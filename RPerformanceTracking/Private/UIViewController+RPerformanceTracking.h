#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (RPerformanceTracking)
@property (nonatomic) uint_fast64_t _rpt_trackingIdentifier;

- (void)_rpt_loadView;
- (void)_rpt_viewDidLoad;
- (void)_rpt_viewWillAppear:(BOOL)animated;
- (void)_rpt_viewDidAppear:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
