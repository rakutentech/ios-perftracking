#import <RPerformanceTracking/RPTPerformanceMeasurement.h>
#import "_RPTTrackingManager.h"

/* RPT_EXPORT */ @implementation RPTPerformanceMeasurement

+ (void)start:(NSString *)identifier {
    [self startAggregated:identifier object:nil];
}

+ (void)end:(NSString *)identifier {
    [self endAggregated:identifier object:nil];
}

+ (void)startAggregated:(NSString *)identifier object:(nullable NSObject *)object {
    [_RPTTrackingManager.sharedInstance startMeasurement:identifier object:object];
}

+ (void)endAggregated:(NSString *)identifier object:(nullable NSObject *)object {
    [_RPTTrackingManager.sharedInstance endMeasurement:identifier object:object];
}
@end
