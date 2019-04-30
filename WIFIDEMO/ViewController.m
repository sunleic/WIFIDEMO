//
//  ViewController.m
//  WIFIDEMO
//
//  Created by limeng on 2019-04-18.
//  Copyright © 2019 sunlei. All rights reserved.
//

#import "ViewController.h"
#import <NetworkExtension/NetworkExtension.h>
#import <CFNetwork/CFNetwork.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <objc/runtime.h>
#import <MBProgressHUD/MBProgressHUD.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "WiFiProxy.h"

@interface ViewController ()<NSURLSessionTaskDelegate>

@property (weak, nonatomic) IBOutlet UITextField *wifiName;
@property (weak, nonatomic) IBOutlet UITextField *wifiPWD;

@end

@implementation ViewController

/*
 目前遇到的问题
 1、iOS9之后（包含iOS9）才可以获取WiFi列表，但是需要申请权限，之前只能获取当前已经连接的WiFi信息。
 2、iOS11之后（包含iOS11）才能控制WiFi的开关，之前需要手动连接。
 3、https://juejin.im/post/5c85cf8ee51d453a637c12df
 
 
 【注意】Network Extension framework 11月10号开始已经不需要申请了，创建APPID的时候勾上就可以，Hotspot Helper API还是需要填写调查问卷申请的
 
 Hotspot Helper API权限申请链接  https://developer.apple.com/contact/network-extension
 周期需要两三周，还可能被拒。
 
 【注意】企业级账号打正式包用的的inHouse权限是要回复那个通过申请的邮件再次申请的,否则In House没有那个选择HotSpotHelper的面板，只有develop和Ad Hoc(打测试包用的)才有那个选择面板，不用填表直接回复邮件告诉他们你是企业账号，需要申请打包In house的证书然后把你之前的填的一些公司teamid 什么的都带上发过去大概一周审核通过。
 
 
 // 回复邮件样例1
 hank you for requesting information about the Network Extension framework. Please note that as of November 10, 2016 this process is not required for developers who wish to use App Proxy, Content Filter, or Packet Tunnel APIs. To use these services please navigate to your Developer Account at <https://developer.apple.com/account/>;; and select the Network Extension capability for the App ID you will be using for your app.
 
 If you are requesting an entitlement for Hotspot Helper APIs your request will be addressed at our earliest convenience.
 
 Regards,
 Developer Technical Support
 Apple Worldwide Developer Relations
 
 
 // 回复邮件样例2
 Thank you for requesting information about the Network Extension framework. Please note that as of November 10, 2016 this process is not required for developers who wish to use App Proxy, Content Filter, or Packet Tunnel APIs. To use these services please navigate to your Developer Account at <https://developer.apple.com/account/&gt; and select the Network Extension capability for the App ID you will be using for your app.
 
 
 // 名称解释
 NEHotspotNetwork 里有如下信息：
 
 SSID：Wifi 名称
 BSSID：站点的 MAC 地址
 signalStrength： Wifi信号强度，该值在0.0-1.0之间
 secure：网络是否安全 (不需要密码的 Wifi，该值为 false)
 autoJoined： 设备是否自动连接该 Wifi，目前测试自动连接以前连过的 Wifi 的也为 false 。
 justJoined：网络是否刚刚加入
 chosenHelper：HotspotHelper是否为网络的所选助手
 
 开发前必看的参考文献
 1、https://www.jianshu.com/p/5072a8485ceb
 2、https://blog.csdn.net/st646889325/article/details/79066115
 3、https://www.jianshu.com/p/655d4e1337ff
 4、https://lpd-ios.github.io/2017/03/09/NEHotspotHelper/    // 很6
 5、https://developer.apple.com/documentation/networkextension/nehotspothelper // 苹果官方文档
 6、https://github.com/42vio/iOS-NetworkExtension-NEHotspotHelper
 7、https://medium.com/@Chandrachudh/connecting-to-preferred-wifi-without-leaving-the-app-in-ios-11-11f04d4f5bd0 // iOS11之后打开WIFI并连接上对应的WIFI
 
 */

#pragma mark -- 懒加载

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"~~~~~%@", [self currnentWIFIInfo]);
    [self getWifiList];
    [self getPrivateMethod];
    [self setProxy];
//    [self createVPN];
    
    
}

#pragma mark -- actions

- (IBAction)switchWIFI:(UIButton *)sender {
    [self openSpecialWIFI];
}

- (IBAction)disconnectWIFI:(UIButton *)sender {
    [self disconnectWIFI];
}


- (IBAction)openVPN:(UIButton *)sender {
    NSError *startError;
    [[NEVPNManager sharedManager].connection startVPNTunnelAndReturnError:&startError];
    if(startError) {
        NSLog(@"Start error: %@", startError.localizedDescription);
    }
}


#pragma mark -- test functions

- (void)createVPN {
    NEVPNManager *manager = [NEVPNManager sharedManager];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vpnConnectionStatusChanged) name:NEVPNStatusDidChangeNotification object:nil];
    [manager loadFromPreferencesWithCompletionHandler:^(NSError *error) {
        if(error) {
            NSLog(@"Load error: %@", error);
        }}];
    NEVPNProtocolIPSec *p = [[NEVPNProtocolIPSec alloc] init];
    p.username = @"ppppp";
//    p.passwordReference = [KeyChainAccess loadDataForServiceNamed:@"VIT"];
    p.serverAddress = @"192.168.0.1";
    p.authenticationMethod = NEVPNIKEAuthenticationMethodCertificate;
//    p.localIdentifier = @“[My Local identifier]”;
//    p.remoteIdentifier = @“[My Remote identifier]”;
    p.useExtendedAuthentication = NO;
//    p.identityData = [My VPN certification private key];
    p.disconnectOnSleep = NO;
    [manager setProtocol:p];
    [manager setOnDemandEnabled:NO];
    [manager setLocalizedDescription:@"VIT VPN"];
    NSArray *array = [NSArray new];
    [manager setOnDemandRules: array];
    NSLog(@"Connection desciption: %@", manager.localizedDescription);
    NSLog(@"VPN status:  %i", manager.connection.status);
    [manager loadFromPreferencesWithCompletionHandler:^(NSError *error) {
        // do config stuff
        [manager saveToPreferencesWithCompletionHandler:^(NSError *error) {
        }];
    }];
}

- (void)setProxy {
    NEProxySettings *proxySetting = [[NEProxySettings alloc] init];
    [proxySetting setHTTPEnabled:YES];
    NEProxyServer *server = [[NEProxyServer alloc] initWithAddress:@"http://www.baidu.com" port:80];
    [proxySetting setHTTPServer:server];
    NEPacketTunnelNetworkSettings *networkSetting = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"http://www.baidu.com"];
    networkSetting.proxySettings = proxySetting;
}

// 获取当前WiFi的信息，only need open Access WIFI information on capacities
- (NSDictionary *)currnentWIFIInfo {
    NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
    NSLog(@"interfaces:%@",ifs);
    NSDictionary *info = nil;
    for (NSString *ifname in ifs) {
        info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
        NSLog(@"%@ => %@", ifname, info);
        if (info && [info count]) { break; }
    }
    return info;
}

/*
 iOS11之后（包含iOS11）才可以切换WIFI（如果没有手动打开WIFI，则会打开WIFI），此操作无需申请权限，只需要开启Hotspot configuration 和network extension capability
 iOS11之前只能通过用户手动去操作
 https://stackoverflow.com/questions/47060649/nehotspotconfigurationerrordomain-code-8-internal-error
 */
- (void)openSpecialWIFI {
    NSLog(@"要连接的WIFI信息：\nWiFi名称：%@\nWiFi密码：%@", self.wifiName.text, self.wifiPWD.text);
    
    if (@available(iOS 11.0, *)) { // 用代码自动切换到指定的WiFi热点
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.removeFromSuperViewOnHide = YES;

        NEHotspotConfiguration *netConfig = [[NEHotspotConfiguration alloc] initWithSSID:self.wifiName.text passphrase:self.wifiPWD.text isWEP:NO];
        /*
        // NEHotspotConfiguration可以创建两种形式的WIFI，一种是临时模式joinOnce（默认为NO），另一种是永久模式persistent，
        // 当使用临时模式时：（https://developer.apple.com/documentation/networkextension/nehotspotconfiguration/2887518-joinonce）
            1、临时模式当APP在后台超过15秒就自动断开指定的WIFI了
            2、设备睡眠状态
            3、本APP crash、退出或者卸载
            4、本APP连接了另一个WIFI
            5、用户手动连接了另一个WIFI
        */
        netConfig.joinOnce = NO;

        // 1、移除网络配置，关闭网络
        [self disconnectWIFI];

        // 2、打开网络，调用此方法系统会自动弹窗确认
        [[NEHotspotConfigurationManager sharedManager] applyConfiguration:netConfig completionHandler:^(NSError * _Nullable error) {

            if (error) {
                NSLog(@"无法连接热点：%@",error);

                NSString *msg = @"连接异常!";
                if (error.code == 13) {
                    msg = @"已经连接上了~";
                } else if (error.code == 7) { // 用户点击了弹出框的取消按钮
                    msg = @"您点击了取消按钮!";
                } else {
                    msg = [NSString stringWithFormat:@"%@ 无法连接热点 %@", self.wifiName.text,error.localizedDescription];
                }

                hud.mode = MBProgressHUDModeText;
                hud.label.text = msg;
                [hud showAnimated:YES];
                [hud hideAnimated:YES afterDelay:1.5f];
            } else {
                //连接wifi成功
                NSLog(@"连接WiFi成功");

                hud.mode = MBProgressHUDModeText;
                hud.label.text = [NSString stringWithFormat:@"%@ 连接成功~",self.wifiName.text];
                [hud showAnimated:YES];
                [hud hideAnimated:YES afterDelay:1.5f];
                
                WiFiProxy *proxy = [WiFiProxy sharedInstance];
                [proxy setProxy:@"192.168.1.101" port:8888];
            }
            // 打印所有已经配置过的WIFI
            [self getAllConfiguredWIFIList];
        }];
    } else { // 需要手动去连接WiFi
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"提示" message:@"您必须手动连接上指定的WIFI才能使用该功能，请点击右上角查看具体操作!" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self openWIFISettingPage];
        }];
        [alertVC addAction:sureAction];
        [self presentViewController:alertVC animated:YES completion:^{
        }];
    }
}

- (void)openWIFISettingPage {
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"App-Prefs:root=WIFI"] options:@{} completionHandler:^(BOOL success) {
        }];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"prefs:root=WIFI"]];
    }
}

// 断开指定的已经连接的WIFI，但是不会关闭WIFI功能，有可能会自动连接上其他WIFI
- (void)disconnectWIFI {
    [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:self.wifiName.text];
}

//获取已经配置过（也就是已经被保存过的WIFI）的wifi名称。如果你设置joinOnce为YES,这里就不会有了
-(void)getAllConfiguredWIFIList {
    [[NEHotspotConfigurationManager sharedManager] getConfiguredSSIDsWithCompletionHandler:^(NSArray<NSString *> * _Nonnull list) {
        NSLog(@"所有已经配置过的WIFI列表~~~ %@", list);
    }];
}
    
// 获取WiFi列表，需要手动开启WiFi，从settings进入WiFi列表后，回调才起作用，此操作需要向Apple申请权限
-(void)getWifiList {
    
    // iOS9 之前无法获取WiFi列表
    if (!([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0)) return;
    
    // iOS9之后可以获取WiFi列表，对WiFi进行一些操作，比如给指定的WiFi设置密码
    NSMutableDictionary* options = [[NSMutableDictionary alloc] init];
    [options setObject:@"🔑😀新网程-点我上网😀🔑" forKey:kNEHotspotHelperOptionDisplayName];
    
    dispatch_queue_t queue = dispatch_queue_create("com.pronetwayXY", NULL);
    BOOL returnType = [NEHotspotHelper registerWithOptions:options queue:queue handler: ^(NEHotspotHelperCommand * cmd) {
        NEHotspotNetwork* network;
        NSLog(@"COMMAND TYPE:   %ld", (long)cmd.commandType);
        [cmd createResponse:kNEHotspotHelperResultAuthenticationRequired];
        if (cmd.commandType == kNEHotspotHelperCommandTypeEvaluate || cmd.commandType ==kNEHotspotHelperCommandTypeFilterScanList) {
            NSLog(@"WIFILIST:   %@", cmd.networkList);
            for (network  in cmd.networkList) {
                // NSLog(@"COMMAND TYPE After:   %ld", (long)cmd.commandType);
                if ([network.SSID isEqualToString:@"ssid"] || [network.SSID isEqualToString:@"proict_test"]) {
                    
                    NSString* wifiInfoString = [[NSString alloc] initWithFormat: @"---------------------------\nSSID: %@\nMac地址: %@\n信号强度: %f\nCommandType:%ld\n---------------------------\n\n", network.SSID, network.BSSID, network.signalStrength, (long)cmd.commandType];
                    NSLog(@"%@", wifiInfoString);
                   
                    [network setConfidence:kNEHotspotHelperConfidenceHigh];
                    [network setPassword:@"password"];
                    
                    NEHotspotHelperResponse *response = [cmd createResponse:kNEHotspotHelperResultSuccess];
                    NSLog(@"Response CMD %@", response);
                    
                    [response setNetworkList:@[network]];
                    [response setNetwork:network];
                    
                    [response deliver];
                }
            }
        }
    }];
    NSLog(@"result :%d", returnType);
    NSArray *array = [NEHotspotHelper supportedNetworkInterfaces];
    NSLog(@"wifiArray:%@", array);
    NEHotspotNetwork *connectedNetwork = [array lastObject];
    NSLog(@"supported Network Interface: %@", connectedNetwork);
}


// 检查系统是否设置了代理
- (BOOL)checkProxySetting {
    
    NSDictionary *proxySettings = (__bridge NSDictionary *)(CFNetworkCopySystemProxySettings());
    NSArray *proxies = (__bridge NSArray *)(CFNetworkCopyProxiesForURL((__bridge CFURLRef _Nonnull)([NSURL URLWithString:@"https://www.baidu.com"]), (__bridge CFDictionaryRef _Nonnull)(proxySettings)));
    NSLog(@"\n%@",proxies);
    
    NSDictionary *settings = proxies[0];
    NSLog(@"%@",[settings objectForKey:(NSString *)kCFProxyHostNameKey]);
    NSLog(@"%@",[settings objectForKey:(NSString *)kCFProxyPortNumberKey]);
    NSLog(@"%@",[settings objectForKey:(NSString *)kCFProxyTypeKey]);
    
    if ([[settings objectForKey:(NSString *)kCFProxyTypeKey] isEqualToString:@"kCFProxyTypeNone"]) {
        NSLog(@"没设置代理");
        return NO;
    } else {
        NSLog(@"设置了代理");
        return YES;
    }
}

// 给当前请求设置代理
- (void)sessionRequest {
    
    NSString *urlString = @"https://www.baidu.com/";
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    request.HTTPMethod = @"POST";
    NSURLSessionConfiguration *config = [self proxyWithConfig];
    // 创建代理注册对象
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"error~~~:%@",error.localizedDescription);
        } else {
            NSLog(@"NSURLSession got the response [%@]", response);
            NSLog(@"NSURLSession got the data [%@]", data);
        }
    }];
    NSLog(@"Lets fire up the task!");
    [task resume];
}


- (NSURLSessionConfiguration *)proxyWithConfig {
    
    NSString* proxyHost =  @"10.22.98.21";
    NSNumber* proxyPort = [NSNumber numberWithInt:8080];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
//    config.connectionProxyDictionary = @{
//        @"HTTPEnable":@(YES),
//        (id)kCFStreamPropertyHTTPProxyHost:proxyHost,
//        (id)kCFStreamPropertyHTTPProxyPort:proxyPort,
//        @"HTTPSEnable":@YES,
//        (id)kCFStreamPropertyHTTPSProxyHost:proxyHost,
//        (id)kCFStreamPropertyHTTPSProxyPort:proxyPort
//    };
    
    config.connectionProxyDictionary = @{
        @"HTTPEnable": @YES,
        @"HTTPProxy": proxyHost,
        @"HTTPPort": proxyPort,
        @"HTTPSEnable": @YES,
        @"HTTPSProxy": proxyHost,
        @"HTTPSPort": proxyPort,
//        @"SOCKSEnable": @YES,
//        @"SOCKSProxy": proxyHost,
//        @"SOCKSPort": proxyPort
    };
    return config;
}

- (void)getPrivateMethod {
    // NEHotspotConfiguration
    // NEHotspotConfigurationManager
    // NEHotspotConfiguration
    // SCNetworkConfiguration
    
    unsigned int count = 0;
    Method *memberFuncs = class_copyMethodList(NSClassFromString(@"SCNetworkConfiguration"), &count);
    for (int i = 0; i < count; i++) {
        SEL address = method_getName(memberFuncs[i]);
        NSString *methodName = [NSString stringWithCString:sel_getName(address) encoding:NSUTF8StringEncoding];
        NSLog(@"~~~~~~~~~~member method : %@",methodName);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
