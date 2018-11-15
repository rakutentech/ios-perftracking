#import "_RPTConfiguration.h"

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
        BOOL shouldTrackNonMetricMeasurements = YES;
        if ([enableNonMetricMeasurement isKindOfClass:NSNumber.class])  {
            shouldTrackNonMetricMeasurements = [enableNonMetricMeasurement boolValue];
        }

        BOOL shouldSendDataToPerformanceTracking = YES;
        BOOL shouldSendDataToRAT = NO;
        NSDictionary *modules = values[@"modules"];
        if ([modules isKindOfClass:NSDictionary.class] && modules.count) {
            NSNumber* enablePerformanceTracking = modules[@"enablePerformanceTracking"];
            if ([enablePerformanceTracking isKindOfClass:NSNumber.class])  {
                shouldSendDataToPerformanceTracking = [enablePerformanceTracking boolValue];
            }

            NSNumber* enableRat = modules[@"enableRat"];
            if ([enableRat isKindOfClass:NSNumber.class])  {
                shouldSendDataToRAT = [enableRat boolValue];
            }
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
