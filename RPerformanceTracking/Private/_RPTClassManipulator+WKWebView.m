#import "_RPTClassManipulator+WKWebView.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTHelpers.h"
#import "_RPTMeasurement.h"
#import "_RPTRingBuffer.h"

static const void *_RPT_WKWEBVIEW_TRACKINGIDENTIFIER = &_RPT_WKWEBVIEW_TRACKINGIDENTIFIER;

static void startTrackingWithWKWebView(WKWebView *webView)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    [manager.tracker prolongMetric];

    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
    
    NSURL *webViewURL = webView.URL;
    if (!trackingIdentifier && webViewURL)
    {
        trackingIdentifier = [manager.tracker startRequest:[NSURLRequest requestWithURL:webViewURL]];
        if (trackingIdentifier)
        {
            objc_setAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER, [NSNumber numberWithUnsignedLongLong:trackingIdentifier], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

static void endTrackingWithWKWebView(WKWebView *webView)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    [manager.tracker prolongMetric];

    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
    if (trackingIdentifier)
    {
        [manager.tracker end:trackingIdentifier];
        objc_setAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [manager.tracker endMetric];
}

static void updateStatusCodeForWebView(NSInteger statusCode, WKWebView *webView)
{
    _RPTTrackingManager *manager = [_RPTTrackingManager sharedInstance];
    [manager.tracker prolongMetric];

    uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
    if (trackingIdentifier)
    {
        [manager.tracker updateStatusCode:statusCode trackingIdentifier:trackingIdentifier];
    }
}

@implementation _RPTClassManipulator (WKWebView)

+ (void)rpt_swizzleWKWebView
{
    // MARK: WKWebView loadRequest:
    
    /* The block params below are `self` and then the parameters of the swizzled method.
     * Unlike Obj-C method calls a _cmd selector is not passed to a block.
     */
    id loadRequest_swizzle_blockImp = ^id (id<NSObject> selfRef, NSURLRequest *request) {
        RPTLogVerbose(@"loadRequest_swizzle_blockImp called");
        
        if (request.URL) { [[_RPTTrackingManager sharedInstance].tracker prolongMetric]; }
        
        SEL selector = @selector(loadRequest:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:WKWebView.class];
        
        if (originalImp)
        {
            /* ARC requires casting the IMP to the same signature as the original method.
             * loadRequest: returns a WKNavigation so the return type in the cast is `id`.
             * loadRequest: param is a `NSURLRequest` so the full param types are the implicit
             * `id` (selfRef) and `SEL` (selector), and the explicit `NSURLRequest` (request).
             *
             * If the method was void no return would be necessary and the return type would be
             * `void` not `id`.
             */
            return ((id(*)(id, SEL, id))originalImp)(selfRef, selector, request);
        }
        return nil;
    };
    
    /* The type characters below are:
     * first - return type of method, commonly `@` for object or `v` for void
     * second - `@` for implicit self object parameter
     * third - `:` for implicit _cmd method selector parameter
     * after - depends on parameter type
     */
    const char *methodTypes = "@@:@";
    
    [self swizzleSelector:@selector(loadRequest:)
                  onClass:WKWebView.class
        newImplementation:imp_implementationWithBlock(loadRequest_swizzle_blockImp)
                    types:methodTypes];
    
    //  MARK: WKWebView setNavigationDelegate:
    id setNavDelegate_swizzle_blockImp = ^void (id<NSObject> selfRef, id<WKNavigationDelegate> delegate) {
        RPTLogVerbose(@"setNavDelegate_swizzle_blockImp called");
        
        SEL selector = @selector(setNavigationDelegate:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:WKWebView.class];
        if (originalImp)
        {
            if (delegate && !_RPTTrackingManager.sharedInstance.disableSwizzling)
            {
                [_RPTClassManipulator _swizzleWKWebViewNavDelegate:delegate];
            }
            
            // We must swizzle the WKWebView delegate before calling the original method
            // because WebKit appears to save the delegate selectors that the delegate
            // can respond to at the time of the setNavigationDelegate: call
            ((void(*)(id, SEL, id))originalImp)(selfRef, selector, delegate);
        }
    };
    [self swizzleSelector:@selector(setNavigationDelegate:)
                  onClass:WKWebView.class
        newImplementation:imp_implementationWithBlock(setNavDelegate_swizzle_blockImp)
                    types:"v@:@"];
}

+ (void)_swizzleWKWebViewNavDelegate:(id<WKNavigationDelegate>)delegate
{
    Class recipient = delegate.class;
    
    // MARK: WKNavigationDelegate webView:didStartProvisionalNavigation:
    id didStart_swizzle_blockImp = ^(id<NSObject> selfRef, WKWebView *webView, WKNavigation *navigation) {
        RPTLogVerbose(@"didStart_swizzle_blockImp called");
        
        SEL selector = @selector(webView:didStartProvisionalNavigation:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id, id))originalImp)(selfRef, selector, webView, navigation);
        }
        
        startTrackingWithWKWebView(webView);
    };
    [self swizzleSelector:@selector(webView:didStartProvisionalNavigation:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(didStart_swizzle_blockImp)
                    types:"v@:@@"];
    
    // MARK: WKNavigationDelegate webView:didFinishNavigation:
    id didFinishNavigation_swizzle_blockImp = ^(id<NSObject> selfRef, WKWebView *webView, WKNavigation *navigation) {
        RPTLogVerbose(@"didFinishNavigation_swizzle_blockImp called");
        
        SEL selector = @selector(webView:didFinishNavigation:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id, id))originalImp)(selfRef, selector, webView, navigation);
        }
        
        endTrackingWithWKWebView(webView);
    };
    [self swizzleSelector:@selector(webView:didFinishNavigation:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(didFinishNavigation_swizzle_blockImp)
                    types:"v@:@@"];
    
    // MARK: WKNavigationDelegate webView:didFailNavigation:withError:
    id didFailNavigation_swizzle_blockImp = ^(id<NSObject> selfRef, WKWebView *webView, WKNavigation *navigation, NSError *error) {
        RPTLogVerbose(@"didFailNavigation_swizzle_blockImp called");
        
        SEL selector = @selector(webView:didFailNavigation:withError:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id, id, id))originalImp)(selfRef, selector, webView, navigation, error);
        }
        
        endTrackingWithWKWebView(webView);
    };
    [self swizzleSelector:@selector(webView:didFailNavigation:withError:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(didFailNavigation_swizzle_blockImp)
                    types:"v@:@@@"];
    
    // MARK: WKNavigationDelegate webView:didFailProvisionalNavigation:withError:
    id didFailProvisionalNavigation_swizzle_blockImp = ^(id<NSObject> selfRef, WKWebView *webView, WKNavigation *navigation, NSError *error) {
        RPTLogVerbose(@"didFailProvisionalNavigation_swizzle_blockImp called");
        
        SEL selector = @selector(webView:didFailProvisionalNavigation:withError:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id, id, id))originalImp)(selfRef, selector, webView, navigation, error);
        }
        
        endTrackingWithWKWebView(webView);
    };
    [self swizzleSelector:@selector(webView:didFailProvisionalNavigation:withError:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(didFailProvisionalNavigation_swizzle_blockImp)
                    types:"v@:@@@"];
    
    // MARK: WKNavigationDelegate webViewWebContentProcessDidTerminate:
    id webContentProcessDidTerminate_swizzle_blockImp = ^(id<NSObject> selfRef, WKWebView *webView) {
        RPTLogVerbose(@"webContentProcessDidTerminate_swizzle_blockImp called");
        
        SEL selector = @selector(webViewWebContentProcessDidTerminate:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id))originalImp)(selfRef, selector, webView);
        }
        
        endTrackingWithWKWebView(webView);
    };
    [self swizzleSelector:@selector(webViewWebContentProcessDidTerminate:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(webContentProcessDidTerminate_swizzle_blockImp)
                    types:"v@:@"];
    
    // MARK: WKNavigationDelegate webView:didReceiveServerRedirectForProvisionalNavigation:
    id didReceiveServerRedirect_swizzle_blockImp = ^(id<NSObject> selfRef, WKWebView *webView, WKNavigation *navigation) {
        RPTLogVerbose(@"didReceiveServerRedirect_swizzle_blockImp called");
        
        SEL selector = @selector(webView:didReceiveServerRedirectForProvisionalNavigation:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id, id))originalImp)(selfRef, selector, webView, navigation);
        }
        
        if (webView.URL)
        {
            uint_fast64_t trackingIdentifier = [objc_getAssociatedObject(webView, _RPT_WKWEBVIEW_TRACKINGIDENTIFIER) unsignedLongLongValue];
            if (trackingIdentifier)
            {
                _RPTMeasurement *measurement = [[_RPTTrackingManager sharedInstance].ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
                measurement.receiver = webView.URL.absoluteString;
            }
        }
    };
    [self swizzleSelector:@selector(webView:didReceiveServerRedirectForProvisionalNavigation:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(didReceiveServerRedirect_swizzle_blockImp)
                    types:"v@:@@"];

    // MARK: WKNavigationDelegate webView:decidePolicyForNavigationResponse:decisionHandler:
    id decidePolicyForNavigationResponse_swizzle_blockImp = ^(id<NSObject> selfRef, WKWebView *webView, WKNavigationResponse *navigationResponse, void (^decisionHandler)(WKNavigationResponsePolicy)) {
        RPTLogVerbose(@"decidePolicyForNavigationResponse_swizzle_blockImp called");

        SEL selector = @selector(webView:decidePolicyForNavigationResponse:decisionHandler:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id, id, id))originalImp)(selfRef, selector, webView, navigationResponse, decisionHandler);
        }
        else
        {
            decisionHandler(WKNavigationResponsePolicyAllow);
        }

        if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]])
        {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;
            NSString* urlString = webView.URL.absoluteString;
            if (response.URL && [response.URL.absoluteString isEqualToString:urlString])
            {
                updateStatusCodeForWebView(response.statusCode, webView);
            }
        }
    };
    [self swizzleSelector:@selector(webView:decidePolicyForNavigationResponse:decisionHandler:)
                  onClass:recipient
        newImplementation:imp_implementationWithBlock(decidePolicyForNavigationResponse_swizzle_blockImp)
                    types:"v@:@@@?"];
}
@end
