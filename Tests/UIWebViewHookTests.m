@import OCMock;
@import Foundation;
#import <XCTest/XCTest.h>
#import "_RPTTrackingManager.h"
#import "_RPTRingBuffer.h"
#import "_RPTTracker.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"
#import "_RPTConfiguration.h"
#import "_RPTEventWriter.h"
#import "_RPTSender.h"
#import "_RPTClassManipulator.h"

@interface _RPTTracker ()
@property (atomic) _RPTMetric *currentMetric;
@end

@interface _RPTTrackingManager ()
@property (nonatomic) _RPTTracker    *tracker;
@property (nonatomic) _RPTRingBuffer *ringBuffer;
@property (nonatomic) BOOL            disableSwizzling;
@end

@interface UIWebViewHookTests : XCTestCase <UIWebViewDelegate, NSURLSessionTaskDelegate, NSURLSessionDelegate>
@property (nonatomic) _RPTTrackingManager   *trackingManager;
@property (nonatomic) UIWebView             *webView;
@property (nonatomic) NSURLRequest          *defaultRequest;
@end

@interface WebViewController : NSObject <UIWebViewDelegate>
@property (nonatomic) UIWebView             *webView;
@end

@interface WebViewControllerChild : WebViewController <UIWebViewDelegate>
@property (nonatomic) UIWebView             *webViewInChild;
@end

@implementation WebViewController
- (void)webViewDidStartLoad:(UIWebView *)webView
{
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
}
@end

@implementation WebViewControllerChild
- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [super webViewDidStartLoad:webView];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    // intentionally do not call super
}

- (void)methodNotImplementedInSuperclass
{
}
@end

@implementation UIWebViewHookTests

- (void)setUp
{
    [super setUp];
    
    _trackingManager                        = [_RPTTrackingManager sharedInstance];
    _RPTRingBuffer *ringBuffer              = [_RPTRingBuffer.alloc initWithSize:12];
    _trackingManager.ringBuffer             = ringBuffer;
    _RPTMetric *currentMetric               = _RPTMetric.new;
    currentMetric.identifier                = @"metric";
    _trackingManager.tracker                = [_RPTTracker.alloc initWithRingBuffer:ringBuffer
                                                                      currentMetric:currentMetric];
    _trackingManager.disableSwizzling       = NO;
    
    _webView                                = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
    _defaultRequest                         = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com"]];
    _webView.delegate                       = self;
}

- (void)tearDown
{
    [_webView stopLoading];
    _webView.delegate = nil;
    _webView = nil;
}

#pragma MARK: swizzling tests
- (void)testDelegateIsNotNil
{
    XCTAssertNotNil(_webView.delegate);
}

- (void)testProlongMetricCalledOnLoadRequest
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView loadRequest:_defaultRequest];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongMetricCalledOnWebViewDidStartLoad
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.delegate webViewDidStartLoad:_webView];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongMetricCalledOnWebViewDidFinishLoad
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.delegate webViewDidFinishLoad:_webView];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testEndMetricCalledOnWebViewDidFinishLoad
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.delegate webViewDidFinishLoad:_webView];
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongMetricCalledOnWebViewDidFailLoadWithError
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.delegate webView:_webView didFailLoadWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:nil]];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testEndMetricCalledOnWebViewDidFailLoadWithError
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.delegate webView:_webView didFailLoadWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:nil]];
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

// MARK: Delegate inheritance tests

- (void)testWebViewDelegateSubclassedMethodCallsSuper
{
    id mockTracker = OCMPartialMock(self.trackingManager.tracker);
    
    WebViewControllerChild *child = [self childWebViewController];
    [child.webViewInChild.delegate webViewDidStartLoad:child.webViewInChild];
    
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testWebViewDelegateSubclassedMethodIsForwardedToParent
{
    id mockTracker = OCMPartialMock(self.trackingManager.tracker);
    
    WebViewControllerChild *child = [self childWebViewController];
    [child.webViewInChild.delegate webViewDidFinishLoad:child.webViewInChild];
    
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

// Current swizzle approach doesn't support this case. However, if a subclass
// overrides a method it is usual practice to call super
- (void)DISABLE_testWebViewDelegateSubclassedMethodDoesNotCallSuper
{
    id mockTracker = OCMPartialMock(self.trackingManager.tracker);
    
    WebViewControllerChild *child = [self childWebViewController];
    [child.webViewInChild.delegate webView:child.webViewInChild didFailLoadWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]];
    
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

// MARK: UIWebViewDelegate
- (void)webViewDidStartLoad:(UIWebView *)webView
{
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
}

- (WebViewControllerChild *)childWebViewController
{
    WebViewController *parent = WebViewController.new;
    parent.webView = [UIWebView.alloc initWithFrame:CGRectMake(0, 0, 200, 300)];
    parent.webView.delegate = parent;
    
    WebViewControllerChild *child = WebViewControllerChild.new;
    child.webViewInChild = [UIWebView.alloc initWithFrame:CGRectMake(0, 0, 200, 300)];
    child.webViewInChild.delegate = child;
    
    return child;
}

@end

