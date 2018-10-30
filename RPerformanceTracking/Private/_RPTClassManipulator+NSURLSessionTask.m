#import "_RPTClassManipulator+NSURLSessionTask.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTHelpers.h"
#import <objc/runtime.h>

void _handleChangedState(NSURLSessionTask *task, NSURLSessionTaskState state);

@implementation _RPTClassManipulator (NSURLSessionTask)

+ (void)load
{
    [self _swizzleTaskSetState];
}

/*
 * Provide a unique key for associated object
 */
- (void)_rpt_sessionTask_trackingIdentifier
{
}

void _handleChangedState(NSURLSessionTask *task, NSURLSessionTaskState state)
{
    if (!task) { return; }
    
    NSURLRequest *request = nil;
    if ([task respondsToSelector:@selector(originalRequest)])
    {
        request = task.originalRequest;
    }
    
    if (!request) return;
    
    if (state == NSURLSessionTaskStateRunning)
    {
        // We can get more than 1 StateRunning calls for each task. We should only start
        // the request if it is not already tracked
        uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(task, @selector(_rpt_sessionTask_trackingIdentifier)) unsignedLongLongValue];
        
        if (!trackingIdentifier)
        {
            trackingIdentifier = [_RPTTrackingManager.sharedInstance.tracker startRequest:request];
            
            if (trackingIdentifier)
            {
                objc_setAssociatedObject(task, @selector(_rpt_sessionTask_trackingIdentifier), [NSNumber numberWithUnsignedLongLong:trackingIdentifier], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    }
    else if (state == NSURLSessionTaskStateCompleted)
    {
        uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(task, @selector(_rpt_sessionTask_trackingIdentifier)) unsignedLongLongValue];
        if (trackingIdentifier)
        {
            _RPTTracker *tracker = _RPTTrackingManager.sharedInstance.tracker;
            NSInteger statusCode = 0;
            if ([task.response isKindOfClass:[NSHTTPURLResponse class]])
            {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
                statusCode = httpResponse.statusCode;
                [tracker sendResponseHeaders:httpResponse.allHeaderFields.copy trackingIdentifier:trackingIdentifier];
            }
            [tracker updateStatusCode:statusCode trackingIdentifier:trackingIdentifier];
            [tracker end:trackingIdentifier];
        }
    }
}

+ (void)_swizzleTaskSetState
{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    NSURL *testURL = [NSURL URLWithString:@"https://www.rakuten.co.jp"];
    
    // We need to create NSURLSessionXxxxxTask instance to find out the underlying class
    // e.g. NSURLSessionDataTask is a __NSCFLocalDataTask
    NSURLSessionDataTask *dataTask  = [session dataTaskWithURL:testURL];
    Class dataTaskClass             = dataTask.class;
    [dataTask cancel];
    
    // The 'from' class below is the public NSURLSessionXxxxxTask and the 'to' class
    // below is the underlying class of NSURLSessionTask, which is the common superclass
    // of DataTask (which is the superclass of UploadTask) and DownloadTask
    id setState_swizzle_blockImp = ^void (id<NSObject> selfRef, NSURLSessionTaskState state) {
        RPTLogVerbose(@"setState_swizzle_blockImp called : %ld", (long)state);

        _handleChangedState((NSURLSessionTask *)selfRef, state);
        
        SEL selector = NSSelectorFromString(@"setState:");
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:dataTaskClass];
        
        if (originalImp)
        {
            ((void(*)(id, SEL, NSURLSessionTaskState))originalImp)(selfRef, selector, state);
        }
    };
    
    [self swizzleSelector:NSSelectorFromString(@"setState:")
                  onClass:dataTaskClass
        newImplementation:imp_implementationWithBlock(setState_swizzle_blockImp)
                    types:"v@:l"];
    
    [session invalidateAndCancel];
}

@end
