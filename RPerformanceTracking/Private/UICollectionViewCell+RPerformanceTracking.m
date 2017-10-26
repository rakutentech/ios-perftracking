#import "UICollectionViewCell+RPerformanceTracking.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"

@implementation UICollectionViewCell (RPerformanceTracking)

- (void)_rpt_setSelected:(BOOL)selected
{
    if (selected)
    {
        [[_RPTTrackingManager sharedInstance].tracker endMetric];
    }
    [self _rpt_setSelected:selected];
}

@end
