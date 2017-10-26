#import "_RPTNSURLProtocol.h"
#import "_RPTSessionChallengeSender.h"
#import "_RPTTrackingManager.h"
#import "_RPTConfiguration.h"
#import "_RPTTracker.h"
#import <objc/runtime.h>

static NSString *const RPTCustomProtocolKey = @"RPTCustomProtocolKey";
extern NSURLCacheStoragePolicy CacheStoragePolicyForRequestAndResponse(NSURLRequest * request, NSHTTPURLResponse * response);

static const void *_RPT_NSURLPROTOCOL_TRACKINGIDENTIFIER = &_RPT_NSURLPROTOCOL_TRACKINGIDENTIFIER;

static void endTrackingWithNSURLSessionTask(NSURLSessionTask *task)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    
    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(task, _RPT_NSURLPROTOCOL_TRACKINGIDENTIFIER) unsignedLongLongValue];
    
    if (trackingIdentifier)
    {
        [manager.tracker end:trackingIdentifier];
    }
    objc_setAssociatedObject(task, _RPT_NSURLPROTOCOL_TRACKINGIDENTIFIER, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void startTrackingRequestOnNSURLSessionTask(NSURLRequest *request, NSURLSessionTask *task)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    
    NSString *redirectURLString = request.URL.absoluteString;
    
    if (!redirectURLString.length) return;
    
    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(task, _RPT_NSURLPROTOCOL_TRACKINGIDENTIFIER) unsignedLongLongValue];
    
    // if trackingId is non-zero it means there is already a request being tracked
    if (!trackingIdentifier)
    {
        trackingIdentifier = [manager.tracker startRequest:request];
        if (trackingIdentifier)
        {
            objc_setAssociatedObject(task, _RPT_NSURLPROTOCOL_TRACKINGIDENTIFIER, [NSNumber numberWithUnsignedLongLong:trackingIdentifier], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

@interface _RPTNSURLProtocol()<NSURLSessionDelegate, NSURLSessionTaskDelegate>
@property (nonatomic, strong) NSURLSessionDataTask *connection;

@end
@implementation _RPTNSURLProtocol

// FIXME : fix "-Wnullable-to-nonnull-conversion" && "-Wunused-parameter" warning, then remove pragma
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
#pragma clang diagnostic ignored "-Wunused-parameter"

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSString *scheme = request.URL.scheme.lowercaseString;
    if (![request.URL.absoluteString containsString:[_RPTTrackingManager sharedInstance].configuration.eventHubURL.absoluteString] &&
        (![NSURLProtocol propertyForKey:RPTCustomProtocolKey inRequest:request] && (([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]))))
    {
        return YES;
    }

    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:RPTCustomProtocolKey inRequest:newRequest];
    NSURLSessionConfiguration* config = NSURLSessionConfiguration.defaultSessionConfiguration;
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config  delegate:self delegateQueue:nil];
    self.connection = [session dataTaskWithRequest:newRequest];
    [self.connection resume];
}

- (void)stopLoading
{
    [self.connection cancel];
}


- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSURLCacheStoragePolicy cacheStoragePolicy;
    if ([response isKindOfClass:[NSHTTPURLResponse class]])
    {
        cacheStoragePolicy = CacheStoragePolicyForRequestAndResponse(self.request, (NSHTTPURLResponse *) response);
    }
    else
    {
        cacheStoragePolicy = NSURLCacheStorageNotAllowed;
    }
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:cacheStoragePolicy];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    // Start the redirect tracking
    startTrackingRequestOnNSURLSessionTask(request, task);
    completionHandler(request);
}


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    endTrackingWithNSURLSessionTask(task);
    if (error)
    {
        [self.client URLProtocol:self didFailWithError:error];
    }
    else
    {
        [self.client URLProtocolDidFinishLoading:self];
    }
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    _RPTSessionChallengeSender *sender = [[_RPTSessionChallengeSender alloc] initWithSessionCompletionHandler:completionHandler];
    NSURLAuthenticationChallenge* challengeWrapper = [[NSURLAuthenticationChallenge alloc] initWithAuthenticationChallenge:challenge sender:sender];
    [self.client URLProtocol:self didReceiveAuthenticationChallenge:challengeWrapper];
}

// Based on https://developer.apple.com/library/content/samplecode/CustomHTTPProtocol/Listings/Read_Me_About_CustomHTTPProtocol_txt.html
extern NSURLCacheStoragePolicy CacheStoragePolicyForRequestAndResponse(NSURLRequest * request, NSHTTPURLResponse * response)
{
    BOOL                        cacheable;
    NSURLCacheStoragePolicy       result;
    
    // Check the request can be cacheable based on status code?

    switch ([response statusCode])
    {
        case 200:
        case 203:
        case 206:
        case 301:
        case 304:
        case 404:
        case 410:
        {
            cacheable = YES;
        } break;
            
        default:
        {
            cacheable = NO;
        } break;
    }
    
    if (cacheable)
    {
        NSString *responseHeader;
        
        responseHeader = [[response allHeaderFields][@"Cache-Control"] lowercaseString];
        if ( (responseHeader != nil) && [responseHeader rangeOfString:@"no-store"].location != NSNotFound)
        {
            cacheable = NO;
        }
    }
    
    // If we still think it might be cacheable, look at the "Cache-Control" header in
    // the request.
    
    if (cacheable)
    {
        NSString *  requestHeader;
        
        requestHeader = [[request allHTTPHeaderFields][@"Cache-Control"] lowercaseString];
        if ( (requestHeader != nil)
            && ([requestHeader rangeOfString:@"no-store"].location != NSNotFound)
            && ([requestHeader rangeOfString:@"no-cache"].location != NSNotFound) )
        {
            cacheable = NO;
        }
    }
    
    // Use the cacheable flag to determine the result.
    
    if (cacheable)
    {
        if ([[[[request URL] scheme] lowercaseString] isEqual:@"https"])
        {
            result = NSURLCacheStorageAllowedInMemoryOnly;
        }
        else
        {
            result = NSURLCacheStorageAllowed;
        }
    }
    else
    {
        result = NSURLCacheStorageNotAllowed;
    }
    
    return result;
}

@end
