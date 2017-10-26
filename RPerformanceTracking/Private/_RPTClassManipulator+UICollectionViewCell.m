#import "_RPTClassManipulator+UICollectionViewCell.h"
#import "UICollectionViewCell+RPerformanceTracking.h"

@implementation _RPTClassManipulator (UICollectionViewCell)

+ (void)load
{
    [_RPTClassManipulator addMethodFromClass:UICollectionViewCell.class
                                withSelector:@selector(_rpt_setSelected:)
                                     toClass:UICollectionViewCell.class
                                   replacing:@selector(setSelected:)
                               onlyIfPresent:NO];
}

@end
