@import OCMock;
@import Foundation;
#import <XCTest/XCTest.h>
#import "_RPTTrackingManager.h"
#import "_RPTRingBuffer.h"
#import "_RPTTracker.h"
#import "_RPTMetric.h"
#import "_RPTClassManipulator.h"
#import "_RPTNSURLProtocol.h"

@interface _RPTTracker ()
@property (atomic) _RPTMetric *currentMetric;
@end

@interface _RPTTrackingManager ()
@property (nonatomic) _RPTTracker    *tracker;
@property (nonatomic) _RPTRingBuffer *ringBuffer;
@end

@interface _RPTNSURLProtocol ()
+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;
- (void)startLoading;
- (void)stopLoading;
@end

@interface URLProtocolTests : XCTestCase <NSURLSessionTaskDelegate, NSURLSessionDelegate>
@property (nonatomic) _RPTTrackingManager   *urlProtocolTrackingManager;
@property (nonatomic) UIWebView             *webView;
@property (nonatomic) NSURLRequest          *defaultRequest;
@property (nonatomic) id                     managerClassMock;
@end

@implementation URLProtocolTests

- (void)setUp {
    [super setUp];
    _urlProtocolTrackingManager             = [[_RPTTrackingManager alloc] init];
    _RPTRingBuffer *ringBuffer             = [_RPTRingBuffer.alloc initWithSize:12];
    _urlProtocolTrackingManager.ringBuffer  = ringBuffer;
    _RPTMetric *currentMetric              = _RPTMetric.new;
    currentMetric.identifier                = @"metric";
    _urlProtocolTrackingManager.tracker     = [_RPTTracker.alloc initWithRingBuffer:ringBuffer
                                                                      currentMetric:currentMetric];
    _urlProtocolTrackingManager.disableProtocolWebviewObserving = NO;

    _managerClassMock = OCMClassMock(_RPTTrackingManager.class);
    OCMStub([_managerClassMock sharedInstance]).andReturn(_urlProtocolTrackingManager);

    _webView                                = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
    _defaultRequest                         = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com"]];

    // We need to register the _RPTNSURLProtocol class here because the "+load" method is called before the "setup" method.
    [NSURLProtocol registerClass:[_RPTNSURLProtocol class]];
}

- (void)tearDown {
    [super tearDown];
    [_webView stopLoading];
    _webView.delegate = nil;
    _webView = nil;
    [_managerClassMock stopMocking];
}

#pragma MARK: custom NSURLProtocol tests

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

- (void)testCanonicalRequestCalledOnWebViewLoadRequest
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

@end
