#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Track metrics.
 *
 * @class RPTPerformanceMetric RPTPerformanceMetric.h <RPerformanceTracking/RPerformanceTracking.h>
 *
 * @ingroup PerformanceTrackingMetricAPI
 */
RPT_EXPORT @interface RPTPerformanceMetric : NSObject

/**
 * @param identifier Identifier of the metric to start tracking.
 */
+ (void)start:(NSString *)identifier;

/**
 * Prolong an existing metric.
 */
+ (void)prolong;

/**
 * End an existing metric.
 */
+ (void)end;
@end

NS_ASSUME_NONNULL_END
