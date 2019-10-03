@import Darwin.POSIX.sys.utsname;

#import "_RPTEnvironment.h"

#define RPT_EXPAND_AND_QUOTE0(s) #s
#define RPT_EXPAND_AND_QUOTE(s) RPT_EXPAND_AND_QUOTE0(s)

#ifndef RPT_SDK_VERSION
#define RPT_SDK_VERSION 0.0.0
#endif

NSString *const RPTSDKVersion = @RPT_EXPAND_AND_QUOTE(RPT_SDK_VERSION);

@interface _RPTEnvironment (Private)

- (NSString *)determineModelIdentifier;
- (NSURL *)baseURLFromConfig;

@end

@implementation _RPTEnvironment

- (instancetype)init {
    if (self = [super init]) {
        NSBundle *bundle = NSBundle.mainBundle;
        UIDevice *device = UIDevice.currentDevice;

        _appIdentifier = bundle.bundleIdentifier;
        _appVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        _sdkVersion = RPTSDKVersion;

        _modelIdentifier = [self determineModelIdentifier];
        _osVersion = [device.systemVersion copy];

        _relayAppId = [bundle objectForInfoDictionaryKey:@"RPTRelayAppID"];

        _baseURL = [self baseURLFromConfig];

        NSString *bundleKey = [bundle objectForInfoDictionaryKey:@"RASSubscriptionKey"] ?: [bundle objectForInfoDictionaryKey:@"RPTSubscriptionKey"];
        _subscriptionKey = bundleKey.length ? [@"ras-" stringByAppendingString:bundleKey] : nil;

        NSNumber *bundleMaximumMetricDuration = [bundle objectForInfoDictionaryKey:@"RPTMaximumMetricDurationSeconds"];
        _maximumMetricDurationSeconds = bundleMaximumMetricDuration.doubleValue;

        _deviceCountry = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    }

    return self;
}

@end

@implementation _RPTEnvironment (Private)

- (NSString *)determineModelIdentifier {
    struct utsname systemInfo;

    uname(&systemInfo);

    return [NSString stringWithUTF8String:systemInfo.machine];
}

- (NSURL *)baseURLFromConfig {
    NSBundle *bundle = NSBundle.mainBundle;
    NSURL *candidateURL = [NSURL URLWithString:(NSString *)[bundle objectForInfoDictionaryKey:@"RPTConfigAPIEndpoint"]];

    if (candidateURL && candidateURL.scheme && candidateURL.host) {
        return candidateURL;
    }

    return nil;
}

@end
