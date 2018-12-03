#import "_RPTTrackingManager.h"
#import "_RPTClassManipulator+UIWebView.h"
#import <objc/runtime.h>
#import "_RPTTracker.h"
#import "_RPTHelpers.h"
#import "_RPTMeasurement.h"
#import "_RPTRingBuffer.h"

static const void *_RPT_UIWEBVIEW_TRACKINGIDENTIFIER = &_RPT_UIWEBVIEW_TRACKINGIDENTIFIER;

static void startTrackingWithUIWebViewWithRequest(UIWebView *webView, NSURLRequest *request)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    [manager.tracker prolongMetric];

    // bail out if there's no URL
    if (!request.URL) { return; }

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

    NSURLRequest* request = webView.request;
    NSURL *url = request.URL;
    NSCachedURLResponse *urlResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)urlResponse.response;
    NSInteger statusCode = httpResponse.statusCode;

    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_UIWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
    if (trackingIdentifier && url)
    {
        // Update status code
        [manager.tracker updateURL:url trackingIdentifier:trackingIdentifier];
        [manager.tracker updateStatusCode:statusCode trackingIdentifier:trackingIdentifier];
        [manager.tracker end:trackingIdentifier];
        objc_setAssociatedObject(webView, _RPT_UIWEBVIEW_TRACKINGIDENTIFIER, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [manager.tracker endMetric];
}

@implementation _RPTClassManipulator (UIWebView)

+ (void)rpt_swizzleUIWebView
{
    // MARK: UIWebView loadRequest:

    /* The block params below are `self` and then the parameters of the swizzled method.
     * Unlike Obj-C method calls a _cmd selector is not passed to a block.
     */
    id loadRequest_swizzle_blockImp = ^void (id<NSObject> selfRef, NSURLRequest *request) {
        RPTLogVerbose(@"UIWebView loadRequest_swizzle_blockImp called");

        if (request.URL) { [[_RPTTrackingManager sharedInstance].tracker prolongMetric]; }
        if ([selfRef isKindOfClass:UIWebView.class])
        {
            UIWebView *webView = (UIWebView*)selfRef;
            startTrackingWithUIWebViewWithRequest(webView, request);
        }
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
            if (delegate && !_RPTTrackingManager.sharedInstance.disableSwizzling)
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

    // MARK: UIWebViewDelegate webViewDidFinishLoad:
    id webViewDidFinishLoad_swizzle_blockImp = ^(id<NSObject> selfRef, UIWebView *webView) {
        RPTLogVerbose(@"UIWevView webViewDidFinishLoad_swizzle_blockImp called");

        SEL selector = @selector(webViewDidFinishLoad:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id))originalImp)(selfRef, selector, webView);
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
