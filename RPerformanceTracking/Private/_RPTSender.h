#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class _RPTRingBuffer, _RPTConfiguration, _RPTMetric, _RPTEventWriter;

RPT_EXPORT @interface _RPTSender : NSObject

- (instancetype)initWithRingBuffer:(_RPTRingBuffer *)ringBuffer
                     configuration:(_RPTConfiguration *)configuration
                     currentMetric:(_RPTMetric *)currentMetric
                       eventWriter:(_RPTEventWriter *)eventWriter NS_DESIGNATED_INITIALIZER;

/*
 * Start running the Sender background queue to process items from the ring buffer
 */
- (void)start;

/*
 * Stop processing items on the background Sender queue
 */
- (void)stop;
@end

NS_ASSUME_NONNULL_END
