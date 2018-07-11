#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

RPT_EXPORT NSString* const RPTSDKVersion;

RPT_EXPORT @interface _RPTEnvironment : NSObject

@property (nonatomic, readonly, copy, nullable) NSString* appIdentifier;
@property (nonatomic, readonly, copy, nullable) NSString* appVersion;
@property (nonatomic, readonly, copy, nullable) NSString* sdkVersion;

@property (nonatomic, copy, readonly) NSString* modelIdentifier;
@property (nonatomic, copy, readonly) NSString* osVersion;

@property (nonatomic, readonly, copy, nullable) NSString* relayAppId;

@property (nonatomic, readonly, copy, nullable) NSURL* performanceTrackingBaseURL;
@property (nonatomic, readonly, copy, nullable) NSString* performanceTrackingSubscriptionKey;

@property (nonatomic, readonly, copy, nullable) NSString* deviceCountry;

@end

NS_ASSUME_NONNULL_END
