#import "WKWebView+RPerformanceTracking.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTMeasurement.h"
#import "_RPTRingBuffer.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static const void *_RPT_WKWEBVIEW_TRACKINGIDENTIFIER = &_RPT_WKWEBVIEW_TRACKINGIDENTIFIER;

static void endTrackingWithWKWebView(WKWebView *webView)
{
    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
    if (trackingIdentifier)
    {
        [_RPTTrackingManager.sharedInstance.tracker end:trackingIdentifier];
    }
    objc_setAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [[_RPTTrackingManager sharedInstance].tracker prolongMetric];
    [[_RPTTrackingManager sharedInstance].tracker endMetric];
}

@implementation WKWebView (RPerformanceTracking)

#pragma mark Swizzle methods

- (WKNavigation *)_rpt_loadRequest:(NSURLRequest *)request
{
    if (request)
    {
        [[_RPTTrackingManager sharedInstance].tracker prolongMetric];
    }
    return [self _rpt_loadRequest:request];
}

- (WKWebView *)_rpt_webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    if (!navigationAction.targetFrame.isMainFrame)
    {
        [[_RPTTrackingManager sharedInstance].tracker prolongMetric];
    }
    
    // createWebViewWithConfiguration is an optional WKUIDelegate method, though the documentation states
    // "If you do not implement this method, the web view will cancel the navigation" so it's reasonable to expect
    // that apps will implement it
    if ([self respondsToSelector:@selector(_rpt_webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)])
    {
        return [self _rpt_webView:webView createWebViewWithConfiguration:configuration forNavigationAction:navigationAction windowFeatures:windowFeatures];
    }
    else
    {
        // The app hasn't implemented createWebViewWithConfiguration
        //
        // The documentation states the method should return a "new web view or nil" and that "WebKit will load the request
        // in the returned web view". We don't want to crash the app by calling an unrecognized selector but we should
        // return a sensible default
        return nil;
    }
}

- (void)_rpt_webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    [[_RPTTrackingManager sharedInstance].tracker prolongMetric];
    
    if ([self respondsToSelector:@selector(_rpt_webView:decidePolicyForNavigationAction:decisionHandler:)])
    {
        [self _rpt_webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
    }
}

- (void)_rpt_webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [[_RPTTrackingManager sharedInstance].tracker prolongMetric];

    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];

    if (!trackingIdentifier && webView.URL)
    {
        trackingIdentifier = [_RPTTrackingManager.sharedInstance.tracker startRequest:[NSURLRequest requestWithURL:webView.URL]];
        if (trackingIdentifier)
        {
            objc_setAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER, [NSNumber numberWithUnsignedLongLong:trackingIdentifier], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    if ([self respondsToSelector:@selector(_rpt_webView:didStartProvisionalNavigation:)])
    {
        [self _rpt_webView:webView didStartProvisionalNavigation:navigation];
    }
}

- (void)_rpt_webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    endTrackingWithWKWebView(webView);

    if ([self respondsToSelector:@selector(_rpt_webView:didFailNavigation:withError:)])
    {
        [self _rpt_webView:webView didFailNavigation:navigation withError:error];
    }
}

- (void)_rpt_webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    endTrackingWithWKWebView(webView);

    if ([self respondsToSelector:@selector(_rpt_webView:didFailProvisionalNavigation:withError:)])
    {
        [self _rpt_webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
}

- (void)_rpt_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    endTrackingWithWKWebView(webView);
    
    if ([self respondsToSelector:@selector(_rpt_webView:didFinishNavigation:)])
    {
        [self _rpt_webView:webView didFinishNavigation:navigation];
    }
}

- (void)_rpt_webViewWebContentProcessDidTerminate:(WKWebView *)webView
{
    endTrackingWithWKWebView(webView);

    if ([self respondsToSelector:@selector(_rpt_webViewWebContentProcessDidTerminate:)])
    {
        [self _rpt_webViewWebContentProcessDidTerminate:webView];
    }
}

- (void)_rpt_webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation
{
    if (webView.URL)
    {
        uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
        if (trackingIdentifier)
        {
            _RPTMeasurement *measurement = [[_RPTTrackingManager sharedInstance].ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
            measurement.receiver = webView.URL.absoluteString;
        }
    }

    if ([self respondsToSelector:@selector(_rpt_webView:didReceiveServerRedirectForProvisionalNavigation:)])
    {
        [self _rpt_webView:webView didReceiveServerRedirectForProvisionalNavigation:navigation];
    }
}

@end
