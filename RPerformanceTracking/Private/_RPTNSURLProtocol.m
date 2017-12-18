#import "_RPTNSURLProtocol.h"
#import "_RPTSessionChallengeSender.h"
#import "_RPTTrackingManager.h"
#import "_RPTConfiguration.h"
#import "_RPTTracker.h"
#import <objc/runtime.h>

static NSString *const RPTCustomProtocolKey = @"RPTCustomProtocolKey";
extern NSURLCacheStoragePolicy CacheStoragePolicyForRequestAndResponse(NSURLRequest * request, NSHTTPURLResponse * response);

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
    
    NSString *eventHubURLString = [_RPTTrackingManager sharedInstance].configuration.eventHubURL.absoluteString;
    BOOL isHTTP = [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
    
    // if config response is invalid the eventHubURL string below will be nil, which causes an exception in containsString, so make sure len > 0
    BOOL isRPTURL = eventHubURLString.length && [request.URL.absoluteString containsString:eventHubURLString];

    if (!isRPTURL && isHTTP && ![[NSURLProtocol propertyForKey:RPTCustomProtocolKey inRequest:request] boolValue])
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
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:newRequest];
    if (!dataTask) return;
    
    self.connection = dataTask;
    
    // we are generating a NSURLSessionTask to load this request therefore tracking loading
    // state will be handled by NSURLSessionTask+RPerformanceTracking#_rpt_setState:
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
    if (!response)
    {
        completionHandler(request);
        return;
    }
    
    // Remove the property so that the redirect is treated as a new request
    NSMutableURLRequest *newRequest = [request mutableCopy];
    [NSURLProtocol removePropertyForKey:RPTCustomProtocolKey inRequest:newRequest];
    
    [self.client URLProtocol:self wasRedirectedToRequest:newRequest redirectResponse:response];
    completionHandler(nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
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
