#import "_RPTClassManipulator+UITableViewCell.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTHelpers.h"
#import <objc/runtime.h>

@implementation _RPTClassManipulator (UITableViewCell)

+ (void)rpt_swizzleUITableViewCell
{
    id setSelected_swizzle_blockImp = ^void (id<NSObject> selfRef, BOOL selected) {
        RPTLogVerbose(@"UITableViewCell setSelected_swizzle_blockImp called");

        if (selected)
        {
            [[_RPTTrackingManager sharedInstance].tracker endMetric];
        }
        SEL selector = @selector(setSelected:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:UITableViewCell.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL, BOOL))originalImp)(selfRef, selector, selected);
        }
    };
    [self swizzleSelector:@selector(setSelected:)
                  onClass:UITableViewCell.class
        newImplementation:imp_implementationWithBlock(setSelected_swizzle_blockImp)
                    types:"v@:B"];
}
@end
