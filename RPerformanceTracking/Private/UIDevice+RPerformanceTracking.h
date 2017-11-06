#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (RPerformanceTracking)

- (int64_t)freeDeviceMemory;
- (int64_t)totalDeviceMemory;
- (int64_t)usedAppMemory;

@end

NS_ASSUME_NONNULL_END
