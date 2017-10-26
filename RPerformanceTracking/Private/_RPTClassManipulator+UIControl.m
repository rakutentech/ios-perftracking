#import "_RPTClassManipulator+UIControl.h"
#import "UIControl+RPerformanceTracking.h"

@implementation _RPTClassManipulator (UIControl)

+ (void)load
{
    [_RPTClassManipulator addMethodFromClass:UIControl.class
                                withSelector:@selector(_rpt_sendAction:to:forEvent:)
                                     toClass:UIControl.class
                                   replacing:@selector(sendAction:to:forEvent:)
                               onlyIfPresent:NO];
}

@end
