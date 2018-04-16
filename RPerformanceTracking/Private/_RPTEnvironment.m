@import Darwin.POSIX.sys.utsname;

#import "_RPTEnvironment.h"

@interface _RPTEnvironment(Private)

-(NSString*)determineModelIdentifier;
-(NSURL*)performanceTrackingBaseURLFromConfig;

@end

@implementation _RPTEnvironment

-(instancetype)init {
    if (self = [super init]) {
        NSBundle* bundle = NSBundle.mainBundle;
        UIDevice* device = UIDevice.currentDevice;
        
        _appIdentifier = bundle.bundleIdentifier;
        _appVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        
        _modelIdentifier = [self determineModelIdentifier];
        _osVersion = [device.systemVersion copy];
        
        _relayAppId = [bundle objectForInfoDictionaryKey:@"RPTRelayAppID"];
        
        _performanceTrackingBaseURL = [self performanceTrackingBaseURLFromConfig];
        _performanceTrackingSubscriptionKey = [bundle objectForInfoDictionaryKey:@"RPTSubscriptionKey"];
        
        _deviceCountry = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    }
    
    return self;
}

@end

@implementation _RPTEnvironment(Private)

-(NSString*)determineModelIdentifier {
    struct utsname systemInfo;
    
    uname(&systemInfo);
    
    return [NSString stringWithUTF8String:systemInfo.machine];
}

-(NSURL*)performanceTrackingBaseURLFromConfig {
    NSBundle* bundle = NSBundle.mainBundle;
    NSURL *candidateURL = [NSURL URLWithString:(NSString*)[bundle objectForInfoDictionaryKey:@"RPTConfigAPIEndpoint"]];
    
    if (candidateURL && candidateURL.scheme && candidateURL.host) {
        return candidateURL;
    }
    
    return nil;
}


@end
