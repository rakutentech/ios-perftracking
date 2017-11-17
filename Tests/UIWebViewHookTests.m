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
#import "UIWebView+RPerformanceTracking.h"
#import "_RPTNSURLProtocol.h"

@interface _RPTTracker ()
@property (atomic) _RPTMetric *currentMetric;
@end

@interface _RPTTrackingManager ()
@property (nonatomic) _RPTTracker    *tracker;
@property (nonatomic) _RPTRingBuffer *ringBuffer;
@end

@interface _RPTClassManipulator ()
- (void)_rpt_setDelegate:(id<UIWebViewDelegate>)delegate;
@end

@interface _RPTNSURLProtocol ()
+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;
- (void)startLoading;
- (void)stopLoading;

@end

@interface UIWebViewHookTests : XCTestCase <UIWebViewDelegate, NSURLSessionTaskDelegate, NSURLSessionDelegate>
@property (nonatomic) _RPTTrackingManager   *trackingManager;
@property (nonatomic) UIWebView             *webView;
@property (nonatomic) NSURLRequest          *defaultRequest;
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
    
    _webView                                = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
    _defaultRequest                         = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com"]];
    _webView.delegate                       = self;
    [NSURLProtocol registerClass:[_RPTNSURLProtocol class]];
}

- (void)tearDown
{
    // Revert the swizzling that was set up when the WebView delegate was set
    Class recipient = _webView.delegate.class;
    [_RPTClassManipulator addMethodFromClass:recipient
                                withSelector:@selector(webViewDidStartLoad:)
                                     toClass:UIWebView.class
                                   replacing:@selector(_rpt_webViewDidStartLoad:)
                               onlyIfPresent:NO];
    
    [_RPTClassManipulator addMethodFromClass:recipient
                                withSelector:@selector(webViewDidFinishLoad:)
                                     toClass:UIWebView.class
                                   replacing:@selector(_rpt_webViewDidFinishLoad:)
                               onlyIfPresent:NO];
    
    [_RPTClassManipulator addMethodFromClass:recipient
                                withSelector:@selector(webView:didFailLoadWithError:)
                                     toClass:UIWebView.class
                                   replacing:@selector(_rpt_webView:didFailLoadWithError:)
                               onlyIfPresent:NO];

    [_webView stopLoading];
    _webView.delegate = nil;
    _webView = nil;
}

- (void)testSwizzlingMethodLoadRequestIsAddedToUIWebViewClass
{
    XCTAssert([_webView respondsToSelector:@selector(_rpt_webViewLoadRequest:)]);
}

- (void)testOriginalMethodLoadRequestIsPresentInUIWebviewClass
{
    XCTAssert([_webView respondsToSelector:@selector(loadRequest:)]);
}

- (void)testSwizzlingMethodSetDelegateIsAddedToUIWebViewClass
{
    XCTAssert([_webView respondsToSelector:@selector(_rpt_setDelegate:)]);
}

- (void)testOriginalMethodSetDelegateIsPresentInUIWebviewClass
{
    XCTAssert([_webView respondsToSelector:@selector(setDelegate:)]);
}

- (void)testSwizzledSetDelegateCallsOriginalMethod
{
    XCTAssert([_webView.delegate isKindOfClass:[self class]]);
}

- (void)testSwizzlingMethodDidStartLoadIsAddedToUIWebViewDelegate
{
    XCTAssert([_webView.delegate respondsToSelector:@selector(_rpt_webViewDidStartLoad:)]);
}

- (void)testOriginalMethodDidStartLoadIsPresentInUIWebViewDelegate
{
    XCTAssert([_webView.delegate respondsToSelector:@selector(webViewDidStartLoad:)]);
}

- (void)testSwizzlingMethodDidFinishLoadIsAddedToUIWebViewDelegate
{
    XCTAssert([_webView.delegate respondsToSelector:@selector(_rpt_webViewDidFinishLoad:)]);
}

- (void)testOriginalMethodDidFinishLoadIsPresentInUIWebViewDelegate
{
    XCTAssert([_webView.delegate respondsToSelector:@selector(webViewDidFinishLoad:)]);
}

- (void)testSwizzlingMethodDidFailLoadIsAddedToUIWebViewDelegate
{
    XCTAssert([_webView.delegate respondsToSelector:@selector(_rpt_webView:didFailLoadWithError:)]);
}

- (void)testOriginalMethodDidFailLoadIsPresentInUIWebViewDelegate
{
    XCTAssert([_webView.delegate respondsToSelector:@selector(webView:didFailLoadWithError:)]);
}

- (void)testProlongMetricIsCalledOnLoadRequest
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView loadRequest:_defaultRequest];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongMetricIsCalledOnDidStartLoad
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.delegate webViewDidStartLoad:_webView];
    OCMVerify([mockTracker prolongMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongEndMetricIsCalledOnDidFinishLoad
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.delegate webViewDidFinishLoad:_webView];
    OCMVerify([mockTracker prolongMetric]);
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

- (void)testProlongEndMetricIsCalledOnDidFailLoad
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_webView.delegate webView:_webView didFailLoadWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:nil]];
    OCMVerify([mockTracker prolongMetric]);
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

- (void)testCanInitWithRequestCalledOnWebViewLoadRequest
{
    XCTestExpectation *wait = [self expectationWithDescription:@"wait"];
    id mockCustomProtocol = OCMClassMock([_RPTNSURLProtocol class]);
    
    [_webView loadRequest:_defaultRequest];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        OCMVerify([mockCustomProtocol canInitWithRequest:[OCMArg any]]);
        [wait fulfill];
    });
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [mockCustomProtocol stopMocking];
}

- (void)testCannonicalRequestCalledOnWebViewLoadRequest
{
    XCTestExpectation *wait = [self expectationWithDescription:@"wait"];
    id mockCustomProtocol = OCMClassMock([_RPTNSURLProtocol class]);
    
    [_webView loadRequest:_defaultRequest];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        OCMVerify([mockCustomProtocol canonicalRequestForRequest:[OCMArg any]]);
        [wait fulfill];
    });
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [mockCustomProtocol stopMocking];
}

- (void)DISABLED_testStartLoadingCanBeCalled
{
    XCTestExpectation *wait = [self expectationWithDescription:@"wait"];
    _RPTNSURLProtocol *customProtocol = [[_RPTNSURLProtocol alloc] initWithRequest:_defaultRequest cachedResponse:nil client:nil];

    id mock = OCMClassMock([NSURLProtocol class]);
    OCMStub([NSURLProtocol alloc]).andReturn(mock);
    OCMStub([mock initWithRequest:[OCMArg any] cachedResponse:[OCMArg any] client:[OCMArg any]]).andReturn(customProtocol);
    id mockCustomProtocol = OCMPartialMock(customProtocol);
    
    [_webView loadRequest:_defaultRequest];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        OCMVerify([mock startLoading]);
        [wait fulfill];
    });
    [self waitForExpectationsWithTimeout:10 handler:nil];
    [mockCustomProtocol stopMocking];
    [mock stopMocking];
}
- (void)DISABLED_testStopLoadingCanBeCalled
{
    XCTestExpectation *wait = [self expectationWithDescription:@"wait"];
    
    _RPTNSURLProtocol *customProtocol = [[_RPTNSURLProtocol alloc] initWithRequest:_defaultRequest cachedResponse:nil client:nil];
    id mockCustomProtocol = OCMPartialMock(customProtocol);
    [_webView loadRequest:customProtocol.request];
    [_webView stopLoading];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        OCMVerify([mockCustomProtocol stopLoading]);
        [wait fulfill];
    });
    [self waitForExpectationsWithTimeout:2 handler:nil];
    [mockCustomProtocol stopMocking];
    
}
- (void)DISABLED_testNSURLSessionChallegeCalledOnWebViewLoadRequest
{
    id mockProtocol = OCMProtocolMock(@protocol(NSURLSessionDelegate));
    XCTestExpectation *wait = [self expectationWithDescription:@"wait"];
    
    [_webView loadRequest:_defaultRequest];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        OCMVerify([mockProtocol URLSession:[OCMArg any] didReceiveChallenge:[OCMArg any] completionHandler:[OCMArg any]]);
        [wait fulfill];
    });
    [self waitForExpectationsWithTimeout:10 handler:nil];
    [mockProtocol stopMocking];
}

- (void)DISABLED_testNSURLSessionDidCompleteCalledOnWebViewLoadRequest
{
    id mockProtocol = OCMProtocolMock(@protocol(NSURLSessionTaskDelegate));
    XCTestExpectation *wait = [self expectationWithDescription:@"wait"];
    
    [_webView loadRequest:_defaultRequest];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        OCMVerify([mockProtocol URLSession:[OCMArg any] task:[OCMArg any] didCompleteWithError:[OCMArg any]]);
        [wait fulfill];
    });
    [self waitForExpectationsWithTimeout:6 handler:nil];
    [mockProtocol stopMocking];
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

@end
