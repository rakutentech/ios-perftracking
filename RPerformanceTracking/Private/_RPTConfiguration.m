#import "_RPTConfiguration.h"
#import "_RPTHelpers.h"
#import "_RPTEnvironment.h"

static NSString *const KEY = @"com.rakuten.performancetracking";

/* RPT_EXPORT */ @implementation _RPTConfiguration

- (instancetype)initWithData:(NSData *)data
{
    do
    {
        /*
         * Parsing starts here.
         */
        if (![data isKindOfClass:NSData.class] || !data.length) break;

        NSDictionary *values = [NSJSONSerialization JSONObjectWithData:data options:0 error:0];
        if (![values isKindOfClass:NSDictionary.class]) break;

        NSNumber *enablePercent = values[@"enablePercent"];
        if (![enablePercent isKindOfClass:NSNumber.class]) break;

        double activationRatio = enablePercent.doubleValue * 0.01;
        if (activationRatio <= 0.0 || activationRatio > 1.0) break;

        NSString *urlString = values[@"sendUrl"];
        if (![urlString isKindOfClass:NSString.class] || !urlString.length) break;

        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) break;
        
        NSNumber* enableNonMetricMeasurement = values[@"enableNonMetricMeasurement"];
        BOOL shouldTrackNonMetricMeasurements = _RPTNumberToBool(enableNonMetricMeasurement, YES);

        BOOL shouldSendDataToPerformanceTracking = YES;
        BOOL shouldSendDataToRAT = NO;
        NSDictionary *modules = values[@"modules"];
        if ([modules isKindOfClass:NSDictionary.class] && modules.count) {
            NSNumber* enablePerformanceTracking = modules[@"enablePerformanceTracking"];
            shouldSendDataToPerformanceTracking = _RPTNumberToBool(enablePerformanceTracking, YES);

            NSNumber* enableRat = modules[@"enableRat"];
            shouldSendDataToRAT = _RPTNumberToBool(enableRat, NO);
        }

        NSDictionary *headerFields = values[@"sendHeaders"];
        if (![headerFields isKindOfClass:NSDictionary.class]) break;

        BOOL headersAreValid = YES;
        for (NSString *header in headerFields)
        {
            NSString *headerValue = headerFields[header];

            if (![header isKindOfClass:NSString.class] || !header.length ||
                ![headerValue isKindOfClass:NSString.class] || !headerValue.length)
            {
                headersAreValid = NO;
                break;
            }
        }
        if (!headersAreValid) break;

        /*
         * Everything is valid.
         */
        if ((self = [super init]))
        {
            _activationRatio          = activationRatio;
            _eventHubURL              = url;
            _eventHubHTTPHeaderFields = headerFields;
            _shouldTrackNonMetricMeasurements = shouldTrackNonMetricMeasurements;
            _shouldSendDataToPerformanceTracking = shouldSendDataToPerformanceTracking;
            _shouldSendDataToRAT = shouldSendDataToRAT;
        }
        return self;
    } while(0);

    return nil; // invalid object
}

+ (instancetype)loadConfiguration
{
    NSData *configurationData = [NSUserDefaults.standardUserDefaults objectForKey:KEY];
    return configurationData ? [self.alloc initWithData:configurationData] : nil;
}

+ (void)persistWithData:(NSData *)data
{
    if (data.length) [NSUserDefaults.standardUserDefaults setObject:data forKey:KEY];
}
@end

@implementation _RPTConfigurationFetcher

+ (void)fetchWithCompletionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler
{
    _RPTEnvironment* environment = [_RPTEnvironment new];
    
    NSString *relayAppID    = environment.relayAppId;
    NSString *appVersion    = environment.appVersion;
    NSString *sdkVersion    = environment.sdkVersion;
    NSString *country       = environment.deviceCountry;
    
    NSString *path = [NSString stringWithFormat:@"/platform/ios/"];
    if (relayAppID.length){ path = [path stringByAppendingString:[NSString stringWithFormat:@"app/%@/", relayAppID]]; }
#if DEBUG
    NSAssert(relayAppID.length, @"Your application's Info.plist must contain a key 'RPTRelayAppID' set to the relay Portal application ID");
#endif
    
    path = [path stringByAppendingString:[NSString stringWithFormat:@"version/%@/", appVersion]];
    
    NSURLSessionConfiguration *sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration;
    
    NSURL *base = environment.performanceTrackingBaseURL;
#if DEBUG
    NSAssert(base, @"Your application's Info.plist must contain a key 'RPTConfigAPIEndpoint' set to the endpoint URL of your Config API");
#endif
    
    NSString *subscriptionKey = environment.performanceTrackingSubscriptionKey;
    if (subscriptionKey.length) { sessionConfiguration.HTTPAdditionalHeaders = @{@"Ocp-Apim-Subscription-Key":subscriptionKey}; }
#if DEBUG
    NSAssert(subscriptionKey.length, @"Your application's Info.plist file must contain a key 'RPTSubscriptionKey' which should be set to your 'Ocp-Apim-Subscription-Key' from the API Portal");
#endif
    
    NSURL *url = [base URLByAppendingPathComponent:path];
    
    if (!url || !base || !subscriptionKey.length || !relayAppID.length)
    {
        // Fail safely in a release build if the info.plist doesn't have the expected key-values
        return;
    }
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    components.query = [NSString stringWithFormat:@"sdk=%@&country=%@&osVersion=%@&device=%@", sdkVersion, country, environment.osVersion, environment.modelIdentifier];
    
    NSURL* configURL = components.URL;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    [[session dataTaskWithURL:configURL completionHandler:^(NSData *data, NSURLResponse *response, NSError * error)
      {
          if (completionHandler)
          {
              completionHandler(data, response, error);
          }
      }] resume];
}

@end
