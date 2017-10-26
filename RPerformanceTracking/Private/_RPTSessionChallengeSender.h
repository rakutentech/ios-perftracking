#import <RPerformanceTracking/RPTDefines.h>

@interface _RPTSessionChallengeSender : NSObject <NSURLAuthenticationChallengeSender>

- (instancetype)initWithSessionCompletionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler;

@end
