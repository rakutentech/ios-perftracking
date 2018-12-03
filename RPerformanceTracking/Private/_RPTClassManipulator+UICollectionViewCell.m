#import "_RPTClassManipulator+UICollectionViewCell.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTHelpers.h"
#import <objc/runtime.h>

@implementation _RPTClassManipulator (UICollectionViewCell)

+ (void)rpt_swizzleUICollectionViewCell
{
    id setSelected_swizzle_blockImp = ^void (id<NSObject> selfRef, BOOL selected) {
        RPTLogVerbose(@"UICollectionViewCell setSelected_swizzle_blockImp called");

        if (selected)
        {
            [[_RPTTrackingManager sharedInstance].tracker endMetric];
        }
        SEL selector = @selector(setSelected:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:UICollectionViewCell.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL, BOOL))originalImp)(selfRef, selector, selected);
        }
    };
    [self swizzleSelector:@selector(setSelected:)
                  onClass:UICollectionViewCell.class
        newImplementation:imp_implementationWithBlock(setSelected_swizzle_blockImp)
                    types:"v@:B"];
}
@end
