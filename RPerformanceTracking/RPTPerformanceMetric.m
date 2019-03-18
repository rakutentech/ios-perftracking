#import <RPerformanceTracking/RPTPerformanceMetric.h>
#import "_RPTTrackingManager.h"

/* RPT_EXPORT */ @implementation RPTPerformanceMetric
+ (void)start:(NSString *)identifier {
    [_RPTTrackingManager.sharedInstance startMetric:identifier];
}

+ (void)prolong {
    [_RPTTrackingManager.sharedInstance prolongMetric];
}
@end
