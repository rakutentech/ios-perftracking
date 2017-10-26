#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIControl (RPerformanceTracking)

- (void)_rpt_sendAction:(SEL)action to:(nullable id)target forEvent:(nullable UIEvent *)event;

@end

NS_ASSUME_NONNULL_END
