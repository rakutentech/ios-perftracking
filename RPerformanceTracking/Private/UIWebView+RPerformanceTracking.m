#import "UIWebView+RPerformanceTracking.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import <objc/runtime.h>

static const void *_RPT_UIWEBVIEW_TRACKINGIDENTIFIER = &_RPT_UIWEBVIEW_TRACKINGIDENTIFIER;

static void endTrackingWithUIWebView(UIWebView *webView)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    
    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_UIWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
    
    if (trackingIdentifier && manager.disableProtocolWebviewObserving)
    {
        [manager.tracker end:trackingIdentifier];
    }
    objc_setAssociatedObject(webView, _RPT_UIWEBVIEW_TRACKINGIDENTIFIER, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [manager.tracker prolongMetric];
    [manager.tracker endMetric];
}

static void startTrackingRequestOnWebView(NSURLRequest *request, UIWebView *webView)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    
    NSString *webViewURLString = request.URL.absoluteString;
    
    // bail out if there's no URL or if tracking is already done by _RPTNSURLProtocol
    if (!webViewURLString.length || !manager.disableProtocolWebviewObserving) return;

    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_UIWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
    
    // if trackingId is non-zero it means there is already a request being tracked
    if (!trackingIdentifier)
    {
        trackingIdentifier = [manager.tracker startRequest:request];
        if (trackingIdentifier)
        {
            objc_setAssociatedObject(webView, _RPT_UIWEBVIEW_TRACKINGIDENTIFIER, [NSNumber numberWithUnsignedLongLong:trackingIdentifier], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

@implementation UIWebView (RPerformanceTracking)

- (void)_rpt_webViewLoadRequest:(NSURLRequest *)request
{
    [[_RPTTrackingManager sharedInstance].tracker prolongMetric];
    startTrackingRequestOnWebView(request, self);
    
    [self _rpt_webViewLoadRequest:request];
}

- (void)_rpt_webViewDidStartLoad:(UIWebView *)webView
{
    [[_RPTTrackingManager sharedInstance].tracker prolongMetric];
    startTrackingRequestOnWebView(webView.request, webView);

    // webViewDidStartLoad: is an optional UIWebViewDelegate method
    if ([self respondsToSelector:@selector(_rpt_webViewDidStartLoad:)])
    {
        [self _rpt_webViewDidStartLoad:webView];
    }
}

- (void)_rpt_webViewDidFinishLoad:(UIWebView *)webView
{
    endTrackingWithUIWebView(webView);
    
    // webViewDidFinishLoad: is an optional UIWebViewDelegate method
    if ([self respondsToSelector:@selector(_rpt_webViewDidFinishLoad:)])
    {
        [self _rpt_webViewDidFinishLoad:webView];
    }
}

- (void)_rpt_webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    endTrackingWithUIWebView(webView);
    
    // webView:didFailLoadWithError: is an optional UIWebViewDelegate method
    if ([self respondsToSelector:@selector(_rpt_webView:didFailLoadWithError:)])
    {
        [self _rpt_webView:webView didFailLoadWithError:error];
    }
}

@end
