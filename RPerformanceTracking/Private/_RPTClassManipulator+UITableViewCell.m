#import "_RPTClassManipulator+UITableViewCell.h"
#import "UICollectionViewCell+RPerformanceTracking.h"

@implementation _RPTClassManipulator (UITableViewCell)

+ (void)load
{
    [_RPTClassManipulator addMethodFromClass:UITableViewCell.class
                                withSelector:@selector(_rpt_setSelected:)
                                     toClass:UITableViewCell.class
                                   replacing:@selector(setSelected:)
                               onlyIfPresent:NO];
}

@end
