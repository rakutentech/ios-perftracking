#import <RPerformanceTracking/RPTPerformanceMeasurement.h>
#import "_RPTTrackingManager.h"

/* RPT_EXPORT */ @implementation RPTPerformanceMeasurement

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

+ (void)start:(NSString *)identifier
{
    [self startAggregated:identifier object:nil];
}

+ (void)end:(NSString *)identifier
{
    [self endAggregated:identifier object:nil];
}

#pragma clang diagnostic pop

+ (void)startAggregated:(NSString *)identifier object:(NSObject *)object
{
    [_RPTTrackingManager.sharedInstance startMeasurement:identifier object:object];
}

+ (void)endAggregated:(NSString *)identifier object:(NSObject *)object
{
    [_RPTTrackingManager.sharedInstance endMeasurement:identifier object:object];
}
@end
