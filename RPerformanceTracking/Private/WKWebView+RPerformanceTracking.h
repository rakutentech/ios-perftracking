#import <RPerformanceTracking/RPTDefines.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKWebView (RPerformanceTracking)
- (WKNavigation *)_rpt_loadRequest:(NSURLRequest *)request;
- (WKWebView *)_rpt_webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures;

- (void)_rpt_webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;
- (void)_rpt_webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation;
- (void)_rpt_webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error;
- (void)_rpt_webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error;
- (void)_rpt_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation;
- (void)_rpt_webViewWebContentProcessDidTerminate:(WKWebView *)webView;
- (void)_rpt_webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation;
@end

NS_ASSUME_NONNULL_END
