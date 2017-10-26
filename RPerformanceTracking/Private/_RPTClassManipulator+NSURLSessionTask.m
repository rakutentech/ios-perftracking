#import "_RPTClassManipulator+NSURLSessionTask.h"
#import "NSURLSessionTask+RPerformanceTracking.h"

@implementation _RPTClassManipulator (NSURLSessionTask)

// FIXME : fix "-Wnullable-to-nonnull-conversion" warning, then remove pragma
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
+ (void)load
{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    
    NSURL *url = [NSURL URLWithString:@"https://www.rakuten.co.jp"];
    
    /* 
     * We need to create NSURLSessionXxxxxTask instance to find out the underlying class
     * e.g. NSURLSessionDataTask is a __NSCFLocalDataTask
     */
    
    NSURLSessionDataTask *dataTask  = [session dataTaskWithURL:url];
    Class dataTaskClass             = dataTask.class;
    Class taskClass                 = NSURLSessionTask.class;
    [dataTask cancel];
    
    /* The 'from' class below is the public NSURLSessionXxxxxTask because we have created a category on that class
     * so we can get access to the task's NSURLRequest `originalRequest`, see NSURLSessionTask+RPerformanceTracking.h
     *
     * The 'to' class below is the underlying class of NSURLSessionTask, which is the common superclass
     * of DataTask (which is the superclass of UploadTask) and DownloadTask
     */
    
    [self addSwizzledSelectorFromClass:taskClass toClass:dataTaskClass];
    
    /*
     * For safety we check that instances of DownloadTask and UploadTask respond to our added selector.
     * If they don't we need to swizzle those classes too.
     */
    
    if (![NSURLSessionDownloadTask instancesRespondToSelector:@selector(_rpt_setState:)])
    {
        NSURLSessionDownloadTask *downloadTask  = [session downloadTaskWithURL:url];
        [self addSwizzledSelectorFromClass:taskClass toClass:downloadTask.class];
        [downloadTask cancel];
    }
    
    if (![NSURLSessionUploadTask instancesRespondToSelector:@selector(_rpt_setState:)])
    {
        NSURLRequest *request                   = [NSURLRequest requestWithURL:url];
        NSURLSessionUploadTask *uploadTask      = [session uploadTaskWithRequest:request
                                                                        fromData:[@"Data" dataUsingEncoding:NSUTF8StringEncoding]];
        [self addSwizzledSelectorFromClass:taskClass toClass:uploadTask.class];
        [uploadTask cancel];
    }
    
    [session invalidateAndCancel];
}
#pragma clang diagnostic pop

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
+ (void)addSwizzledSelectorFromClass:(Class)sender toClass:(Class)recipient
{
    [_RPTClassManipulator addMethodFromClass:sender
                                withSelector:@selector(_rpt_setState:)
                                     toClass:recipient
                                   replacing:@selector(setState:)
                               onlyIfPresent:YES];
}
#pragma clang diagnostic pop
@end
