@import OCMock;
@import Foundation;
#import <XCTest/XCTest.h>
#import "_RPTTrackingManager.h"
#import "_RPTRingBuffer.h"
#import "_RPTTracker.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"
#import "_RPTEventWriter.h"
#import "_RPTSender.h"
#import <WebKit/WebKit.h>
#import "_RPTClassManipulator.h"
#import "WKWebView+RPerformanceTracking.h"

@interface _RPTTrackingManager ()
@property (nonatomic) _RPTTracker    *tracker;
@property (nonatomic) _RPTRingBuffer *ringBuffer;
@end

@interface _RPTClassManipulator ()
- (void)_rpt_setNavigationDelegate:(id<WKNavigationDelegate>)delegate;
- (void)_rpt_setUIDelegate:(id<WKUIDelegate>)delegate;
@end

@interface _RPTTracker ()
@property (atomic) _RPTMetric *currentMetric;
@end

@interface WKWebViewHookTests : XCTestCase <WKUIDelegate, WKNavigationDelegate>
@property (strong, nonatomic) WKWebView *webView;
@end

@implementation WKWebViewHookTests

static _RPTTrackingManager *_trackingManager = nil;

- (void)setUp
{
    [super setUp];
    
    _trackingManager                       = [_RPTTrackingManager sharedInstance];
    _RPTRingBuffer *ringBuffer             = [_RPTRingBuffer.alloc initWithSize:12];
    _trackingManager.ringBuffer             = ringBuffer;
    _RPTMetric *currentMetric              = _RPTMetric.new;
    currentMetric.identifier               = @"metric";
    _trackingManager.tracker                = [_RPTTracker.alloc initWithRingBuffer:ringBuffer
                                                                   currentMetric:currentMetric];
    _webView                               = [[WKWebView alloc] initWithFrame:CGRectZero
                                                                configuration:[[WKWebViewConfiguration alloc] init]];
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"www.google.com"]]];
    _webView.navigationDelegate              = self;
    _webView.UIDelegate                     = self;
}

- (void)tearDown
{
    Class recipient = _webView.navigationDelegate.class;
    [_RPTClassManipulator addMethodFromClass:recipient
                                withSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)
                                     toClass:WKWebView.class
                                   replacing:@selector(_rpt_webView:decidePolicyForNavigationAction:decisionHandler:)
                               onlyIfPresent:NO];
    
    [_RPTClassManipulator addMethodFromClass:recipient
                                withSelector:@selector(webView:didStartProvisionalNavigation:)
                                     toClass:WKWebView.class
                                   replacing:@selector(_rpt_webView:didStartProvisionalNavigation:)
                               onlyIfPresent:NO];
    
    [_RPTClassManipulator addMethodFromClass:recipient
                                withSelector:@selector(webView:didFailNavigation:withError:)
                                     toClass:WKWebView.class
                                   replacing:@selector(_rpt_webView:didFailNavigation:withError:)
                               onlyIfPresent:NO];
    
    [_RPTClassManipulator addMethodFromClass:recipient
                                withSelector:@selector(webView:didFailProvisionalNavigation:withError:)
                                     toClass:WKWebView.class
                                   replacing:@selector(_rpt_webView:didFailProvisionalNavigation:withError:)
                               onlyIfPresent:NO];
    
    [_RPTClassManipulator addMethodFromClass:recipient
                                withSelector:@selector(webView:didFinishNavigation:)
                                     toClass:WKWebView.class
                                   replacing:@selector(_rpt_webView:didFinishNavigation:)
                               onlyIfPresent:NO];
    
    [_RPTClassManipulator addMethodFromClass:_webView.UIDelegate.class
                                withSelector:@selector(webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)
                                     toClass:WKWebView.class
                                   replacing:@selector(_rpt_webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)
                               onlyIfPresent:NO];
    
    _webView.navigationDelegate = nil;
    _webView.UIDelegate   = nil;
}

- (void)testSwizzlingMethodLoadRequestIsAddedToWKWebViewClass
{
    XCTAssert([_webView respondsToSelector:@selector(_rpt_loadRequest:)]);
}

- (void)testOriginalMethodLoadRequestIsPresentInWKWebviewClass
{
    XCTAssert([_webView respondsToSelector:@selector(loadRequest:)]);
}

- (void)testSwizzlingMethodNavigationActionIsAddedToWKWebViewClass
{
    XCTAssert([_webView respondsToSelector:@selector(_rpt_webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)]);
}

- (void)testSwizzlingMethodSetNavigationDelegateIsAddedToWKWebViewClass
{
    XCTAssert([_webView respondsToSelector:@selector(_rpt_setNavigationDelegate:)]);
}

- (void)testOriginalMethodSetNavigationDelegateIsPresentInWKWebviewClass
{
    XCTAssert([_webView respondsToSelector:@selector(setNavigationDelegate:)]);
}

- (void)testSwizzlingMethodSetUIDelegateIsAddedToWKWebViewClass
{
    XCTAssert([_webView respondsToSelector:@selector(_rpt_setUIDelegate:)]);
}

- (void)testOriginalMethodUIDelegateIsPresentInWKWebviewClass
{
    XCTAssert([_webView respondsToSelector:@selector(setUIDelegate:)]);
}

- (void)testIfNavigationDelegateIsNotNil
{
    XCTAssertNotNil(_webView.navigationDelegate);
}

- (void)testProlongMetricCalledOnLoadRequest
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"www.google.com"]]];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongMetricCalledOnWKWebViewDecidePolicyForNavigationAction
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.navigationDelegate webView:_webView
         decidePolicyForNavigationAction:[WKNavigationAction new]
                         decisionHandler:^(WKNavigationActionPolicy policy) {
    }];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongMetricCalledOnWKWebViewDidStartProvisionalNavigation
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.navigationDelegate webView:_webView didStartProvisionalNavigation:WKNavigationTypeLinkActivated];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongMetricCalledOnWKWebViewDidFinishNavigation
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.navigationDelegate webView:_webView didFinishNavigation:WKNavigationTypeLinkActivated];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongMetricCalledOnWKWebViewDidFailNavigation
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.navigationDelegate webView:_webView
                       didFailNavigation:WKNavigationTypeLinkActivated
                               withError:[NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:nil]];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testEndMetricCalledOnWKWebViewDidFailNavigation
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.navigationDelegate webView:_webView
                       didFailNavigation:WKNavigationTypeLinkActivated
                               withError:[NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:nil]];
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

- (void)testEndMetricCalledOnWKWebViewDidFinishNavigation
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.navigationDelegate webView:_webView didFinishNavigation:WKNavigationTypeLinkActivated];
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongMetricCalledOnWKWebviewDidFailProvisionalNavigation
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.navigationDelegate webView:_webView
            didFailProvisionalNavigation:WKNavigationTypeLinkActivated
                               withError:[NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:nil]];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}
- (void)testEndMetricCalledOnWKWebviewDidFailProvisionalNavigation
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.navigationDelegate webView:_webView
            didFailProvisionalNavigation:WKNavigationTypeLinkActivated
                               withError:[NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:nil]];
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}
#pragma MARK: WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
}
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
}

#pragma MARK: WKUIDelegate
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    return [WKWebView new];
}


@end
