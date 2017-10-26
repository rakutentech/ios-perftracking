#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIWebView (RPerformanceTracking)
- (void)_rpt_webViewLoadRequest:(NSURLRequest *)request;
- (void)_rpt_webViewDidStartLoad:(UIWebView *)webView;
- (void)_rpt_webViewDidFinishLoad:(UIWebView *)webView;
- (void)_rpt_webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;
@end

NS_ASSUME_NONNULL_END
