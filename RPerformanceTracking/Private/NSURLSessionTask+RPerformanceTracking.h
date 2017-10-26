#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSessionTask (RPerformanceTracking)

- (void)_rpt_setState:(NSURLSessionTaskState)state;

@end

NS_ASSUME_NONNULL_END
