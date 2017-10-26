#import "UIViewController+RPerformanceTracking.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import <objc/runtime.h>

@implementation UIViewController (RPerformanceTracking)

#pragma mark Added associate tracking identifier
- (uint_fast64_t)_rpt_trackingIdentifier
{
    return [objc_getAssociatedObject(self, @selector(_rpt_trackingIdentifier)) unsignedLongLongValue];
}

- (void)set_rpt_trackingIdentifier:(uint_fast64_t)_rpt_trackingIdentifier
{
    objc_setAssociatedObject(self, @selector(_rpt_trackingIdentifier), [NSNumber numberWithUnsignedLongLong:_rpt_trackingIdentifier], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)_rpt_loadView
{
    _RPTTrackingManager.sharedInstance.currentScreen = NSStringFromClass([self class]);
    uint_fast64_t trackingIdentifier = [[_RPTTrackingManager sharedInstance].tracker startMethod:@"loadView" receiver:self];
    if (trackingIdentifier)
    {
        // associate the tracking identifier to the view controller
        self._rpt_trackingIdentifier = trackingIdentifier;
    }
    [self _rpt_loadView];
}

- (void)_rpt_viewDidLoad
{
    [self _rpt_viewDidLoad];

    // call end method when the viewDidLoad is completed
    uint_fast64_t trackingIdentifier = self._rpt_trackingIdentifier;
    if (trackingIdentifier)
    {
        [[_RPTTrackingManager sharedInstance].tracker end:trackingIdentifier];
    }
}

- (void)_rpt_viewWillAppear:(BOOL)animated
{
    _RPTTrackingManager.sharedInstance.currentScreen = NSStringFromClass([self class]);
    uint_fast64_t trackingIdentifier = [[_RPTTrackingManager sharedInstance].tracker startMethod:@"displayView" receiver:self];
    if (trackingIdentifier)
    {
        // associate the tracking identifier to the view controller
        self._rpt_trackingIdentifier = trackingIdentifier;
    }
    [[_RPTTrackingManager sharedInstance].tracker prolongMetric];
    [self _rpt_viewWillAppear:animated];
}

- (void)_rpt_viewDidAppear:(BOOL)animated
{
    [self _rpt_viewDidAppear:animated];

    // call end method when the viewDidAppear is completed
    uint_fast64_t trackingIdentifier = self._rpt_trackingIdentifier;
    if (trackingIdentifier)
    {
        [[_RPTTrackingManager sharedInstance].tracker end:trackingIdentifier];
    }
}

@end
