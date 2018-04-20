#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface _RPTEnvironment : NSObject

@property (atomic, readonly, nullable) NSString* appIdentifier;
@property (atomic, readonly, nullable) NSString* appVersion;

@property (atomic, readonly) NSString* modelIdentifier;
@property (atomic, readonly) NSString* osVersion;

@property (atomic, readonly, nullable) NSString* relayAppId;

@property (atomic, readonly, nullable) NSURL* performanceTrackingBaseURL;
@property (atomic, readonly, nullable) NSString* performanceTrackingSubscriptionKey;

@property(atomic, readonly, nullable) NSString* deviceCountry;

@end

NS_ASSUME_NONNULL_END
