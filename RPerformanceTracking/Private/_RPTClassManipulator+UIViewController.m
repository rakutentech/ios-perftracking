#import "_RPTClassManipulator+UIViewController.h"
#import "UIViewController+RPerformanceTracking.h"

@implementation _RPTClassManipulator (UIViewController)

+ (void)load
{
    [_RPTClassManipulator addMethodFromClass:UIViewController.class
                                withSelector:@selector(_rpt_loadView)
                                     toClass:UIViewController.class
                                   replacing:@selector(loadView)
                               onlyIfPresent:NO];

    [_RPTClassManipulator addMethodFromClass:UIViewController.class
                                withSelector:@selector(_rpt_viewDidLoad)
                                     toClass:UIViewController.class
                                   replacing:@selector(viewDidLoad)
                               onlyIfPresent:NO];

    [_RPTClassManipulator addMethodFromClass:UIViewController.class
                                withSelector:@selector(_rpt_viewWillAppear:)
                                     toClass:UIViewController.class
                                   replacing:@selector(viewWillAppear:)
                               onlyIfPresent:NO];

    [_RPTClassManipulator addMethodFromClass:UIViewController.class
                                withSelector:@selector(_rpt_viewDidAppear:)
                                     toClass:UIViewController.class
                                   replacing:@selector(viewDidAppear:)
                               onlyIfPresent:NO];
}
@end
