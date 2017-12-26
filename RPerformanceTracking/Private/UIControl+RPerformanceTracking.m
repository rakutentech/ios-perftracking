#import "UIControl+RPerformanceTracking.h"
#import "_RPTTracker.h"
#import "_RPTTrackingManager.h"
#import "_RPTHelpers.h"

@implementation UIControl (RPerformanceTracking)

- (BOOL)controlEventEndsMetricOnTarget:(id)target withAction:(SEL)action
{
    NSString *actionName = NSStringFromSelector(action);
    
    // UIControlEvents enum constant UIControlEventPrimaryActionTriggered was introduced in
    // iOS 9.0 but there is no way to check enum availability at runtime. Instead check that
    // UIStackView (also introduced in iOS 9.0) is available
    BOOL primaryActionTriggeredAvailable = NSClassFromString(@"UIStackView");
    
    return ([[self actionsForTarget:target forControlEvent:UIControlEventTouchUpInside] containsObject:actionName] ||
            (primaryActionTriggeredAvailable && [[self actionsForTarget:target forControlEvent:UIControlEventPrimaryActionTriggered] containsObject:actionName]) ||
            [[self actionsForTarget:target forControlEvent:UIControlEventValueChanged] containsObject:actionName]);
}

- (void)_rpt_sendAction:(SEL)action to:(nullable id)target forEvent:(nullable UIEvent *)event
{
    if (target && [self controlEventEndsMetricOnTarget:target withAction:action])
    {
        [[_RPTTrackingManager sharedInstance].tracker endMetric];
    }
    
    // Enable the log below for extra debug output
    //RPTLog(@"sendAction %@ toTarget %@", NSStringFromSelector(action), target);
    
    [self _rpt_sendAction:action to:target forEvent:event];
}

@end
