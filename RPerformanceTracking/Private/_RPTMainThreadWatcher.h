#import <Foundation/Foundation.h>

@interface _RPTMainThreadWatcher : NSThread
- (instancetype)initWithThreshold:(NSTimeInterval)threshold;
@end
