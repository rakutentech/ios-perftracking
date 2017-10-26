#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN
@class _RPTMeasurement;

RPT_EXPORT @interface _RPTRingBuffer : NSObject
@property (nonatomic, readonly) NSUInteger size;

- (nullable _RPTMeasurement *)measurementAtIndex:(NSUInteger)index;
- (nullable _RPTMeasurement *)measurementWithTrackingIdentifier:(uint_fast64_t)trackingIdentifier;
- (nullable _RPTMeasurement *)nextMeasurement;

- (instancetype)initWithSize:(NSUInteger)size NS_DESIGNATED_INITIALIZER;
@end
NS_ASSUME_NONNULL_END
