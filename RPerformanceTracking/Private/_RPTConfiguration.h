#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

RPT_EXPORT @interface _RPTConfigurationFetcher : NSObject

/*
 * Fetch configuration from server
 */
+ (void)fetchWithCompletionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

RPT_EXPORT @interface _RPTConfiguration : NSObject
/*
 * URL to send tracking data to.
 */
@property (nonatomic, readonly) NSURL *eventHubURL;

/*
 * Additional headers to set on the requests.
 */
@property (nonatomic, readonly) NSDictionary <NSString *, NSString *> *eventHubHTTPHeaderFields;

/*
 * The ratio of devices that should enable tracking.
 */
@property (nonatomic, readonly) double activationRatio;

/*
 * Should track events when no metric available
 */
@property (nonatomic, readonly) BOOL shouldTrackNonMetricMeasurements;

/*
 * Should send data to PerformanceTracking endpoint
 */
@property (nonatomic, readonly) BOOL shouldSendDataToPerformanceTracking;

/*
 * Should send data to RAT endpoint
 */
@property (nonatomic, readonly) BOOL shouldSendDataToRAT;

/*
 * Load configuration from disk if it exists there, or return the default configuration if not.
 */
+ (instancetype)loadConfiguration;

/*
 * Save configuration based on data obtained from the configuration API.
 */
+ (void)persistWithData:(NSData *)data;

- (instancetype)initWithData:(NSData *)data;
@end

NS_ASSUME_NONNULL_END
