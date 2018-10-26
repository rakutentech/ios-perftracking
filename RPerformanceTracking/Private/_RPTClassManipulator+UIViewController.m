#import "_RPTClassManipulator+UIViewController.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTHelpers.h"
#import <objc/runtime.h>

static const void *_RPT_UIVIEWCONTROLLER_TRACKINGIDENTIFIER = &_RPT_UIVIEWCONTROLLER_TRACKINGIDENTIFIER;

@implementation _RPTClassManipulator (UIViewController)

+ (void)rpt_swizzleUIViewController
{
    id loadView_swizzle_blockImp = ^void (id<NSObject> selfRef) {
        RPTLogVerbose(@"UIViewController loadView_swizzle_blockImp called");

        _RPTTrackingManager.sharedInstance.currentScreen = NSStringFromClass([selfRef class]);
        uint_fast64_t trackingIdentifier = [[_RPTTrackingManager sharedInstance].tracker startMethod:@"loadView" receiver:selfRef];
        if (trackingIdentifier)
        {
            // associate the tracking identifier to the view controller
            objc_setAssociatedObject(selfRef, _RPT_UIVIEWCONTROLLER_TRACKINGIDENTIFIER, [NSNumber numberWithUnsignedLongLong:trackingIdentifier], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        SEL selector = @selector(loadView);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:UIViewController.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL))originalImp)(selfRef, selector);
        }
    };
    [self swizzleSelector:@selector(loadView)
                  onClass:UIViewController.class
        newImplementation:imp_implementationWithBlock(loadView_swizzle_blockImp)
                    types:"v@:"];

    id viewDidLoad_swizzle_blockImp = ^void (id<NSObject> selfRef) {
        RPTLogVerbose(@"UIViewController viewDidLoad_swizzle_blockImp called");

        uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(selfRef, _RPT_UIVIEWCONTROLLER_TRACKINGIDENTIFIER) unsignedLongLongValue];
        if (trackingIdentifier)
        {
            [[_RPTTrackingManager sharedInstance].tracker end:trackingIdentifier];
        }

        SEL selector = @selector(viewDidLoad);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:UIViewController.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL))originalImp)(selfRef, selector);
        }
    };
    [self swizzleSelector:@selector(viewDidLoad)
                  onClass:UIViewController.class
        newImplementation:imp_implementationWithBlock(viewDidLoad_swizzle_blockImp)
                    types:"v@:"];

    id viewWillAppear_swizzle_blockImp = ^void (id<NSObject> selfRef, BOOL animated) {
        RPTLogVerbose(@"UIViewController viewWillAppear_swizzle_blockImp called");

        _RPTTrackingManager.sharedInstance.currentScreen = NSStringFromClass([selfRef class]);
        uint_fast64_t trackingIdentifier = [[_RPTTrackingManager sharedInstance].tracker startMethod:@"displayView" receiver:selfRef];
        if (trackingIdentifier)
        {
            // associate the tracking identifier to the view controller
            objc_setAssociatedObject(selfRef, _RPT_UIVIEWCONTROLLER_TRACKINGIDENTIFIER, [NSNumber numberWithUnsignedLongLong:trackingIdentifier], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [[_RPTTrackingManager sharedInstance].tracker prolongMetric];

        SEL selector = @selector(viewWillAppear:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:UIViewController.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL, BOOL))originalImp)(selfRef, selector, animated);
        }
    };
    [self swizzleSelector:@selector(viewWillAppear:)
                  onClass:UIViewController.class
        newImplementation:imp_implementationWithBlock(viewWillAppear_swizzle_blockImp)
                    types:"v@:B"];

    id viewDidAppear_swizzle_blockImp = ^void (id<NSObject> selfRef, BOOL animated) {
        RPTLogVerbose(@"UIViewController viewDidAppear_swizzle_blockImp called");

        uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(selfRef, _RPT_UIVIEWCONTROLLER_TRACKINGIDENTIFIER) unsignedLongLongValue];
        if (trackingIdentifier)
        {
            [[_RPTTrackingManager sharedInstance].tracker end:trackingIdentifier];
        }

        SEL selector = @selector(viewDidAppear:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:UIViewController.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL, BOOL))originalImp)(selfRef, selector, animated);
        }
    };
    [self swizzleSelector:@selector(viewDidAppear:)
                  onClass:UIViewController.class
        newImplementation:imp_implementationWithBlock(viewDidAppear_swizzle_blockImp)
                    types:"v@:B"];
}
@end
