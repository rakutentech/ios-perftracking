#import "_RPTClassManipulator+UIControl.h"
#import "_RPTTracker.h"
#import "_RPTTrackingManager.h"
#import "_RPTHelpers.h"
#import <objc/runtime.h>

@implementation _RPTClassManipulator (UIControl)

+ (void)rpt_swizzleUIControl
{
    id sendAction_swizzle_blockImp = ^void (UIControl *selfRef, SEL action, id target, UIEvent *event) {
        RPTLogVerbose(@"UIControl sendAction_swizzle_blockImp called");

        NSString *actionName = NSStringFromSelector(action);

        // UIControlEvents enum constant UIControlEventPrimaryActionTriggered was introduced in
        // iOS 9.0 but there is no way to check enum availability at runtime. Instead check that
        // UIStackView (also introduced in iOS 9.0) is available
        BOOL primaryActionTriggeredAvailable = NSClassFromString(@"UIStackView");

        BOOL shouldEndMetric = [[selfRef actionsForTarget:target forControlEvent:UIControlEventTouchUpInside] containsObject:actionName] ||
                               (primaryActionTriggeredAvailable && [[selfRef actionsForTarget:target forControlEvent:UIControlEventPrimaryActionTriggered] containsObject:actionName]) ||
                               [[selfRef actionsForTarget:target forControlEvent:UIControlEventValueChanged] containsObject:actionName];
        if (target && shouldEndMetric)
        {
            [[_RPTTrackingManager sharedInstance].tracker endMetric];
        }

        SEL selector = @selector(sendAction:to:forEvent:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:UIControl.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL, SEL, id, id))originalImp)(selfRef, selector, action, target, event);
        }
    };
    [self swizzleSelector:@selector(sendAction:to:forEvent:)
                  onClass:UIControl.class
        newImplementation:imp_implementationWithBlock(sendAction_swizzle_blockImp)
                    types:"v@::@@"];
}

@end
