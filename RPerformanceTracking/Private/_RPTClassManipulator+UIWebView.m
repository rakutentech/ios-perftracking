#import "_RPTTrackingManager.h"
#import "_RPTClassManipulator+UIWebView.h"
#import "_RPTNSURLProtocol.h"
#import <objc/runtime.h>
#import "_RPTTracker.h"
#import "_RPTHelpers.h"
#import "_RPTMeasurement.h"
#import "_RPTRingBuffer.h"

static const void *_RPT_UIWEBVIEW_TRACKINGIDENTIFIER = &_RPT_UIWEBVIEW_TRACKINGIDENTIFIER;

static void startTrackingWithUIWebView(UIWebView *webView)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    [manager.tracker prolongMetric];

    NSURLRequest *request = webView.request;

    // bail out if there's no URL or if tracking is already done by _RPTNSURLProtocol
    if (!request || manager.enableProtocolWebviewTracking) { return; }

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

static void endTrackingWithUIWebView(UIWebView *webView)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    [manager.tracker prolongMetric];
    [manager.tracker endMetric];

    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_UIWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];

    if (trackingIdentifier)
    {
        [manager.tracker end:trackingIdentifier];
    }
    objc_setAssociatedObject(webView, _RPT_UIWEBVIEW_TRACKINGIDENTIFIER, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation _RPTClassManipulator (UIWebView)

+ (void)load
{
    if([_RPTTrackingManager sharedInstance].enableProtocolWebviewTracking)
    {
        [NSURLProtocol registerClass:[_RPTNSURLProtocol class]];
        return;
    }

    [self _swizzleUIWebView];
}

+ (void)_swizzleUIWebView
{
    // MARK: UIWebView loadRequest:

    /* The block params below are `self` and then the parameters of the swizzled method.
     * Unlike Obj-C method calls a _cmd selector is not passed to a block.
     */
    id loadRequest_swizzle_blockImp = ^void (id<NSObject> selfRef, NSURLRequest *request) {
        RPTLogVerbose(@"UIWebView loadRequest_swizzle_blockImp called");

        if (request.URL) { [[_RPTTrackingManager sharedInstance].tracker prolongMetric]; }

        SEL selector = @selector(loadRequest:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:UIWebView.class];

        if (originalImp)
        {
            return ((void(*)(id, SEL, id))originalImp)(selfRef, selector, request);
        }
    };

    [self swizzleSelector:@selector(loadRequest:)
                  onClass:UIWebView.class
        newImplementation:imp_implementationWithBlock(loadRequest_swizzle_blockImp)
                    types:"v@:@"];

    //  MARK: UIWebView setDelegate:
    id setDelegate_swizzle_blockImp = ^void (id<NSObject> selfRef, id<UIWebViewDelegate> delegate) {
        RPTLogVerbose(@"UIWebView setDelegate_swizzle_blockImp called");

        SEL selector = @selector(setDelegate:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:UIWebView.class];
        if (originalImp)
        {
            if (delegate)
            {
                [_RPTClassManipulator _swizzleUIWebViewDelegate:delegate];
            }

            ((void(*)(id, SEL, id))originalImp)(selfRef, selector, delegate);
        }
    };
    [self swizzleSelector:@selector(setDelegate:)
                  onClass:UIWebView.class
        newImplementation:imp_implementationWithBlock(setDelegate_swizzle_blockImp)
                    types:"v@:@"];
}

+ (void)_swizzleUIWebViewDelegate:(id<UIWebViewDelegate>)delegate
{
    Class recipient = delegate.class;

    // MARK: UIWebViewDelegate webViewDidStartLoad:
    id webViewDidStartLoad_swizzle_blockImp = ^(id<NSObject> selfRef, UIWebView *webView) {
        RPTLogVerbose(@"UIWevView webViewDidStartLoad_swizzle_blockImp called");

        SEL selector = @selector(webViewDidStartLoad:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id))originalImp)(selfRef, selector, webView);
        }

        startTrackingWithUIWebView(webView);
    };
    [self swizzleSelector:@selector(webViewDidStartLoad:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(webViewDidStartLoad_swizzle_blockImp)
                    types:"v@:@"];

    // MARK: UIWebViewDelegate webViewDidFinishLoad:
    id webViewDidFinishLoad_swizzle_blockImp = ^(id<NSObject> selfRef, UIWebView *webView) {
        RPTLogVerbose(@"UIWevView webViewDidFinishLoad_swizzle_blockImp called");

        SEL selector = @selector(webViewDidFinishLoad:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id))originalImp)(selfRef, selector, webView);
        }

        NSCachedURLResponse *urlResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:webView.request];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)urlResponse.response;
        if (httpResponse.URL)
        {
            uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_UIWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
            if (trackingIdentifier)
            {
                [_RPTTrackingManager.sharedInstance.tracker updateStatusCode:httpResponse.statusCode trackingIdentifier:trackingIdentifier];
            }
        }

        endTrackingWithUIWebView(webView);
    };
    [self swizzleSelector:@selector(webViewDidFinishLoad:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(webViewDidFinishLoad_swizzle_blockImp)
                    types:"v@:@"];

    // MARK: UIWebViewDelegate webView:didFailLoadWithError:
    id webViewDidFailLoadWithError_swizzle_blockImp = ^(id<NSObject> selfRef, UIWebView *webView, NSError *error) {
        RPTLogVerbose(@"UIWevView webViewDidFailLoadWithError_swizzle_blockImp called");

        SEL selector = @selector(webView:didFailLoadWithError:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id, id))originalImp)(selfRef, selector, webView, error);
        }

        endTrackingWithUIWebView(webView);
    };
    [self swizzleSelector:@selector(webView:didFailLoadWithError:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(webViewDidFailLoadWithError_swizzle_blockImp)
                    types:"v@:@@"];
}

@end
