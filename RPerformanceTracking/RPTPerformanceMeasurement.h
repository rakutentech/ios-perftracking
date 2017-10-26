#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Track custom measurements.
 *
 * @class RPTPerformanceMeasurement RPTPerformanceMeasurement.h <RPerformanceTracking/RPerformanceTracking.h>
 */
RPT_EXPORT @interface RPTPerformanceMeasurement : NSObject

/**
 * @param identifier Identifier of the measurement to start tracking.
 */
+ (void)start:(NSString *)identifier;

/**
 * @param identifier Identifier of the measurement to stop tracking.
 */
+ (void)end:(NSString *)identifier;

/**
 * @param identifier Identifier of the measurement to start tracking.
 * @param object     Associated object for aggregating the measurement.
 */
+ (void)startAggregated:(NSString *)identifier object:(NSObject *)object;

/**
 * @param identifier Identifier of the measurement to stop tracking.
 * @param object     Associated object for aggregating the measurement.
 */
+ (void)endAggregated:(NSString *)identifier object:(NSObject *)object;
@end

NS_ASSUME_NONNULL_END
