#import "_RPTSessionChallengeSender.h"

// Based on https://stackoverflow.com/questions/27604052/nsurlsessiontask-authentication-challenge-completionhandler-and-nsurlauthenticat

@interface _RPTSessionChallengeSender()

@property (nonatomic, copy) void(^sessionCompletionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential);

@end

@implementation _RPTSessionChallengeSender

// FIXME : fix "-Wunused-parameter" warning, then remove pragma
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
- (instancetype)initWithSessionCompletionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    self = [super init];
    
    if(self)
    {
        self.sessionCompletionHandler = [completionHandler copy];
    }
    
    return self;
}

- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    self.sessionCompletionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    self.sessionCompletionHandler(NSURLSessionAuthChallengeUseCredential, nil);
}

- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    self.sessionCompletionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

- (void)performDefaultHandlingForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    self.sessionCompletionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)rejectProtectionSpaceAndContinueWithChallenge:(NSURLAuthenticationChallenge *)challenge
{
    self.sessionCompletionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
}

@end
