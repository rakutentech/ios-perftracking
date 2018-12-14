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
#import "TestUtils.h"

@interface _RPTTrackingManager ()
@property (nonatomic) _RPTTracker    *tracker;
@property (nonatomic) _RPTRingBuffer *ringBuffer;
@property (nonatomic) BOOL            disableSwizzling;
@end

@interface _RPTTracker ()
@property (atomic) _RPTMetric *currentMetric;
@end

@interface WKWebViewHookTests : XCTestCase <WKNavigationDelegate>
@property (strong, nonatomic) WKWebView *webView;
@end

@implementation WKWebViewHookTests

static _RPTTrackingManager *_trackingManager = nil;

- (void)setUp
{
    [super setUp];
    
    _trackingManager                       = [_RPTTrackingManager sharedInstance];
    _RPTRingBuffer *ringBuffer             = [_RPTRingBuffer.alloc initWithSize:12];
    _trackingManager.ringBuffer            = ringBuffer;
    _RPTMetric *currentMetric              = _RPTMetric.new;
    currentMetric.identifier               = @"metric";
    _RPTConfiguration *config              = mkConfigurationStub(nil);
    _trackingManager.tracker                = [[_RPTTracker alloc] initWithRingBuffer:ringBuffer
                                                                       configuration:config
                                                                       currentMetric:currentMetric];
    _trackingManager.disableSwizzling      = NO;
    _webView                               = [[WKWebView alloc] initWithFrame:CGRectZero
                                                                configuration:[[WKWebViewConfiguration alloc] init]];
    _webView.navigationDelegate            = self;
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com"]]];
}

- (void)tearDown
{
    _webView.navigationDelegate = nil;
}

// MARK: Tests to verify the side effects of our swizzles e.g. has the expected _RPTTracker method been called

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

- (void)testEndMetricCalledOnWKWebviewWebContentProcessDidTerminate
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.navigationDelegate webViewWebContentProcessDidTerminate:_webView];
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

- (void)testWebViewURLAccessedOnDidReceiveServerRedirectForProvisionalNavigation
{
    id wvMock = OCMPartialMock(_webView);
    [_webView.navigationDelegate webView:wvMock didReceiveServerRedirectForProvisionalNavigation:nil];
    OCMVerify([wvMock URL]);
    [wvMock stopMocking];
}

- (void)testProlongMetricCalledOnWebViewDecidePolicyForNavigationResponse
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    id navResponseMock = OCMPartialMock(WKNavigationResponse.new);
    NSHTTPURLResponse *httpResponse = [NSHTTPURLResponse.alloc initWithURL:[NSURL
                                                                            URLWithString:@"https://www.google.com/"]
                                                                statusCode:200
                                                               HTTPVersion:@"HTTP/1.1"
                                                              headerFields:nil];
    OCMStub([navResponseMock response]).andReturn(httpResponse);
    [_webView.navigationDelegate webView:_webView decidePolicyForNavigationResponse:navResponseMock decisionHandler:^(WKNavigationResponsePolicy policy) {
        //
    }];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
    [navResponseMock stopMocking];
}

// MARK: WKNavigationDelegate

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

@end
