#import "_RPTClassManipulator+WKWebView.h"
#import "WKWebView+RPerformanceTracking.h"
#import <WebKit/WebKit.h>

@implementation _RPTClassManipulator (WKWebView)

/*
 * The methods which are swizzled in "+(void)load" method are still ok, because they are done only once during the application lifecycle.
 */
+ (void)load
{
    [_RPTClassManipulator addMethodFromClass:WKWebView.class
                                withSelector:@selector(_rpt_loadRequest:)
                                     toClass:WKWebView.class
                                   replacing:@selector(loadRequest:)
                               onlyIfPresent:NO];

    [_RPTClassManipulator addMethodFromClass:self
                                withSelector:@selector(_rpt_setUIDelegate:)
                                     toClass:WKWebView.class
                                   replacing:@selector(setUIDelegate:)
                               onlyIfPresent:YES];
    
    [_RPTClassManipulator addMethodFromClass:self
                                withSelector:@selector(_rpt_setNavigationDelegate:)
                                     toClass:WKWebView.class
                                   replacing:@selector(setNavigationDelegate:)
                               onlyIfPresent:YES];
}

/*
 * The methods in the WKUIDelegate and WKNavigationDelegate have to be swizzled only once for each delegate.
 */
- (void)_rpt_setUIDelegate:(id<WKUIDelegate>)delegate
{
    if (!delegate) return;
    Class recipient = delegate.class;

    [_RPTClassManipulator swizzleMethodFromClass:WKWebView.class
                                    withSelector:@selector(_rpt_webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)
                                         toClass:recipient
                                       replacing:@selector(webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)
                                   onlyIfPresent:NO];
    
    [self _rpt_setUIDelegate:delegate];
}

- (void)_rpt_setNavigationDelegate:(id<WKNavigationDelegate>)delegate
{
    if (!delegate) return;
    Class recipient = delegate.class;

    [_RPTClassManipulator swizzleMethodFromClass:WKWebView.class
                                    withSelector:@selector(_rpt_webView:decidePolicyForNavigationAction:decisionHandler:)
                                         toClass:recipient
                                       replacing:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)
                                   onlyIfPresent:NO];

    [_RPTClassManipulator swizzleMethodFromClass:WKWebView.class
                                    withSelector:@selector(_rpt_webView:didStartProvisionalNavigation:)
                                         toClass:recipient
                                       replacing:@selector(webView:didStartProvisionalNavigation:)
                                   onlyIfPresent:NO];

    [_RPTClassManipulator swizzleMethodFromClass:WKWebView.class
                                    withSelector:@selector(_rpt_webView:didFailNavigation:withError:)
                                         toClass:recipient
                                       replacing:@selector(webView:didFailNavigation:withError:)
                                   onlyIfPresent:NO];

    [_RPTClassManipulator swizzleMethodFromClass:WKWebView.class
                                    withSelector:@selector(_rpt_webView:didFinishNavigation:)
                                         toClass:recipient
                                       replacing:@selector(webView:didFinishNavigation:)
                                   onlyIfPresent:NO];

    [_RPTClassManipulator swizzleMethodFromClass:WKWebView.class
                                    withSelector:@selector(_rpt_webView:didFailProvisionalNavigation:withError:)
                                         toClass:recipient
                                       replacing:@selector(webView:didFailProvisionalNavigation:withError:)
                                   onlyIfPresent:NO];

    [_RPTClassManipulator swizzleMethodFromClass:WKWebView.class
                                    withSelector:@selector(_rpt_webViewWebContentProcessDidTerminate:)
                                         toClass:recipient
                                       replacing:@selector(webViewWebContentProcessDidTerminate:)
                                   onlyIfPresent:NO];

    [_RPTClassManipulator swizzleMethodFromClass:WKWebView.class
                                    withSelector:@selector(_rpt_webView:didReceiveServerRedirectForProvisionalNavigation:)
                                         toClass:recipient
                                       replacing:@selector(webView:didReceiveServerRedirectForProvisionalNavigation:)
                                   onlyIfPresent:NO];

    [self _rpt_setNavigationDelegate:delegate];
}

@end
