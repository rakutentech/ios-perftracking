#import "_RPTClassManipulator+UIWebView.h"
#import "UIWebView+RPerformanceTracking.h"
#import "_RPTNSURLProtocol.h"
#import "_RPTTrackingManager.h"

@implementation _RPTClassManipulator (UIWebView)

+ (void)load
{
    if(![_RPTTrackingManager sharedInstance].disableProtocolWebviewObserving)
    {
        [NSURLProtocol registerClass:[_RPTNSURLProtocol class]];
        return;
    }
    
    [_RPTClassManipulator addMethodFromClass:UIWebView.class
                                withSelector:@selector(_rpt_webViewLoadRequest:)
                                     toClass:UIWebView.class
                                   replacing:@selector(loadRequest:)
                               onlyIfPresent:NO];
    
    [_RPTClassManipulator addMethodFromClass:self
                                withSelector:@selector(_rpt_setDelegate:)
                                     toClass:UIWebView.class
                                   replacing:@selector(setDelegate:)
                               onlyIfPresent:NO];
}

- (void)_rpt_setDelegate:(id<UIWebViewDelegate>)delegate
{
    [self _rpt_setDelegate:delegate];
    
    if (!delegate) return;
    
    Class recipient = delegate.class;

    [_RPTClassManipulator swizzleMethodFromClass:UIWebView.class
                                    withSelector:@selector(_rpt_webViewDidStartLoad:)
                                         toClass:recipient
                                       replacing:@selector(webViewDidStartLoad:)
                                   onlyIfPresent:NO];

    [_RPTClassManipulator swizzleMethodFromClass:UIWebView.class
                                    withSelector:@selector(_rpt_webViewDidFinishLoad:)
                                         toClass:recipient
                                       replacing:@selector(webViewDidFinishLoad:)
                                   onlyIfPresent:NO];

    [_RPTClassManipulator swizzleMethodFromClass:UIWebView.class
                                    withSelector:@selector(_rpt_webView:didFailLoadWithError:)
                                         toClass:recipient
                                       replacing:@selector(webView:didFailLoadWithError:)
                                   onlyIfPresent:NO];
}

@end
