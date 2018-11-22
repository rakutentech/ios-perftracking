#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class _RPTRingBuffer, _RPTMetric, _RPTConfiguration;

RPT_EXPORT @interface _RPTTracker : NSObject
@property (nonatomic, readonly) _RPTRingBuffer *ringBuffer;

- (void)startMetric:(NSString *)metric;
- (void)prolongMetric;
- (void)endMetric;

- (uint_fast64_t)startMethod:(NSString *)method receiver:(NSObject *)receiver;
- (uint_fast64_t)startRequest:(NSURLRequest *)request;
- (uint_fast64_t)startCustom:(NSString *)custom;
- (uint_fast64_t)addDevice:(NSString *)name start:(NSTimeInterval)startTime end:(NSTimeInterval)endTime;
- (void)end:(uint_fast64_t)trackingIdentifier;
- (void)updateStatusCode:(NSInteger)statusCode trackingIdentifier:(uint_fast64_t)trackingIdentifier;
- (void)updateURL:(NSURL *)url trackingIdentifier:(uint_fast64_t)trackingIdentifier;
- (void)sendResponseHeaders:(NSDictionary *)responseHeaders trackingIdentifier:(uint_fast64_t)trackingIdentifier;

- (instancetype)initWithRingBuffer:(_RPTRingBuffer *)ringBuffer
                     configuration:(_RPTConfiguration *)configuration
                     currentMetric:(_RPTMetric *)currentMetric NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
