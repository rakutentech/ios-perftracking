#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class _RPTConfiguration, _RPTRingBuffer, _RPTTracker, _RPTSender;

RPT_EXPORT @interface _RPTTrackingManager : NSObject
@property (nonatomic, readonly) _RPTConfiguration *configuration;
@property (nonatomic, readonly) _RPTRingBuffer    *ringBuffer;
@property (nonatomic, readonly) _RPTTracker       *tracker;
@property (nonatomic, readonly) _RPTSender        *sender;
@property (nonatomic)           BOOL               disableProtocolWebviewObserving;
@property (nonatomic, copy)     NSString          *currentScreen;

+ (instancetype)sharedInstance;

- (void)startMetric:(NSString *)metric;
- (void)prolongMetric;
- (void)startMeasurement:(NSString *)measurement object:(NSObject *)object;
- (void)endMeasurement:(NSString *)measurement object:(NSObject *)object;
@end

NS_ASSUME_NONNULL_END
