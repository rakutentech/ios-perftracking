#import "NSURLSessionTask+RPerformanceTracking.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import <objc/runtime.h>

@implementation NSURLSessionTask (RPerformanceTracking)

/*
 * self's class is actually __NSCFURLSessionDataTask so we can't call a selector from this category on self.
 * Its sole purpose is to provide a unique key for the call to setAssociatedObject. That's why it just
 * returns void.
 */
- (void)_rpt_trackingIdentifier
{
}

- (void)_rpt_setState:(NSURLSessionTaskState)state
{
    if (state == NSURLSessionTaskStateRunning)
    {
        NSURLRequest *request = self.originalRequest;
        
        // We can get more than 1 StateRunning calls for each task. We should only start
        // the request if it is not already tracked
        uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(self, @selector(_rpt_trackingIdentifier)) unsignedLongLongValue];
        
        if (!trackingIdentifier)
        {
            trackingIdentifier = [_RPTTrackingManager.sharedInstance.tracker startRequest:request];
            
            if (trackingIdentifier)
            {
                objc_setAssociatedObject(self, @selector(_rpt_trackingIdentifier), [NSNumber numberWithUnsignedLongLong:trackingIdentifier], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    }
    else if (state == NSURLSessionTaskStateCompleted)
    {
        uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(self, @selector(_rpt_trackingIdentifier)) unsignedLongLongValue];
        if (trackingIdentifier)
        {
            [_RPTTrackingManager.sharedInstance.tracker end:trackingIdentifier];
        }
    }
    
    [self _rpt_setState:state];
}

@end
