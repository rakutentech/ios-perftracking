#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

RPT_EXPORT @interface _RPTMetric : NSObject<NSCopying>
@property (nonatomic, copy, nullable) NSString *identifier;
@property (atomic) NSTimeInterval startTime;
@property (atomic) NSTimeInterval endTime;
@property (atomic) uint_fast64_t urlCount;

+ (NSTimeInterval)maxDurationInSecs;
- (BOOL)durationLessThanMax;
@end

NS_ASSUME_NONNULL_END
