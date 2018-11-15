#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import "_RPTTracker.h"
#import "_RPTTrackingManager.h"
#import "_RPTSender.h"
#import "_RPTRingBuffer.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"
#import "_RPTClassManipulator+NSURLSessionTask.h"
#import "TestUtils.h"

@interface _RPTTrackingManager ()
@property (nonatomic) _RPTTracker    *tracker;
@property (nonatomic) _RPTRingBuffer *ringBuffer;
@end

@interface NSURLSessionDataTask ()
- (void)setState:(NSURLSessionTaskState)state;
@end

@interface _RPTClassManipulator ()
- (void)_rpt_sessionTask_trackingIdentifier;
@end

@interface NetworkSessionHookTests : XCTestCase <NSURLSessionTaskDelegate>
@property (nonatomic) NSURLSession      *session;
@property (nonatomic) id                 trackerMock;
@property (nonatomic, copy) NSString    *defaultURLString;
@property (nonatomic) NSURL             *defaultURL;
@property (nonatomic) BOOL               taskCompleteDelegateCalled;
@end

@implementation NetworkSessionHookTests

static _RPTTrackingManager *_trackingManager = nil;

+ (void)setUp
{
    [super setUp];
    _trackingManager                         = [_RPTTrackingManager sharedInstance];
}

+ (void)tearDown
{
    [_trackingManager.sender stop];
    _trackingManager = nil;
    [super tearDown];
}

- (void)setUp
{
    [super setUp];
    
    _RPTRingBuffer *ringBuffer  = [_RPTRingBuffer.alloc initWithSize:12];
    _trackingManager.ringBuffer = ringBuffer;
    _RPTConfiguration *config   = mkConfigurationStub(nil);
    _trackingManager.tracker    = [_RPTTracker.alloc initWithRingBuffer:ringBuffer
                                                          configuration:config
                                                          currentMetric:_RPTMetric.new];
    _trackerMock                = OCMPartialMock(_trackingManager.tracker);
    _session                    = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    _defaultURLString           = @"https://www.rakuten.com/test/session_hooks";
    _defaultURL                 = [NSURL URLWithString:_defaultURLString];
    _taskCompleteDelegateCalled = NO;
}

- (void)tearDown
{
    [_session invalidateAndCancel];
    [OHHTTPStubs removeAllStubs];
    [_trackerMock stopMocking];
    [super tearDown];
}

#pragma mark - NSURLSessionDataTask tests

- (void)testThatTrackerStartsRequestWhenDataTaskResumed
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:_defaultURL];
    [dataTask resume];
    
    OCMVerify([_trackerMock startRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURLRequest *request = (NSURLRequest *)obj;
        return  [request isKindOfClass:NSURLRequest.class] &&
                [request isEqual:dataTask.originalRequest] &&
                [request.URL.absoluteString isEqualToString:self.defaultURLString];
    }]]);
}

- (void)testThatTrackerDoesNotStartRequestWhenDataTaskCreated
{
    [self setupStubsWithStatusCode:200];
    
    OCMStub([_trackerMock startRequest:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        XCTFail(@"startRequest should not be called");
    });
    
    [_session dataTaskWithURL:_defaultURL];
}

- (void)testThatTrackerEndsRequestWhenDataTaskCompleted
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:_defaultURL];
    [dataTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:dataTask statusCode:200];
}

- (void)testThatTrackerEndsRequestWhenDataTaskHasCompletionHandler
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:_defaultURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssert(data.length);
        XCTAssertNotNil(response);
    }];
    [dataTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:dataTask statusCode:200];
}

- (void)testThatTrackerEndsRequestWhenDataTaskHasDelegate
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:_defaultURL];
    [dataTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:dataTask statusCode:200];
    XCTAssert(_taskCompleteDelegateCalled);
    [session invalidateAndCancel];
}

- (void)testThatTrackerEndsRequestWhenDataTaskFailed
{
    [self setupStubsWithStatusCode:500]; // Internal server error
    
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:_defaultURL];
    [dataTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:dataTask statusCode:500];
}

- (void)testThatTrackerEndsRequestWhenDataTaskCancelled
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:_defaultURL];
    [dataTask resume];
    [dataTask cancel];
    
    [self assertThatTrackerEndsRequestForSessionTask:dataTask];
}

- (void)testThatTrackerEndsRequestWhenDataTaskErrorOccurred
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:self.defaultURLString];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithError:[NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil]];
    }];
    
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:_defaultURL];
    [dataTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:dataTask];
}

#pragma mark - NSURLSessionDownloadTask tests

- (void)testThatTrackerStartsRequestWhenDownloadTaskResumed
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSessionDownloadTask *downloadTask = [_session downloadTaskWithURL:_defaultURL];
    [downloadTask resume];
    
    OCMVerify([_trackerMock startRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURLRequest *request = (NSURLRequest *)obj;
        return  [request isKindOfClass:NSURLRequest.class] &&
        [request isEqual:downloadTask.originalRequest] &&
        [request.URL.absoluteString isEqualToString:self.defaultURLString];
    }]]);
}

- (void)testThatTrackerDoesNotStartRequestWhenDownloadTaskCreated
{
    [self setupStubsWithStatusCode:200];
    
    OCMStub([_trackerMock startRequest:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        XCTFail(@"startRequest should not be called");
    });
    
    [_session downloadTaskWithURL:_defaultURL];
}

- (void)testThatTrackerEndsRequestWhenDownloadTaskCompleted
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSessionDownloadTask *downloadTask = [_session downloadTaskWithURL:_defaultURL];
    [downloadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:downloadTask statusCode:200];
}

- (void)testThatTrackerEndsRequestWhenDownloadTaskHasCompletionHandler
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSessionDownloadTask *downloadTask = [_session downloadTaskWithURL:_defaultURL completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
       
        XCTAssertNotNil(response);
        XCTAssertNotNil(location);
    }];
    [downloadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:downloadTask statusCode:200];
}

- (void)testThatTrackerEndsRequestWhenDownloadTaskHasDelegate
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:_defaultURL];
    [downloadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:downloadTask statusCode:200];
    XCTAssert(_taskCompleteDelegateCalled);
    [session invalidateAndCancel];
}

- (void)testThatTrackerEndsRequestWhenDownloadTaskFailed
{
    [self setupStubsWithStatusCode:500]; // Internal server error
    
    NSURLSessionDownloadTask *downloadTask = [_session downloadTaskWithURL:_defaultURL];
    [downloadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:downloadTask statusCode:500];
}

- (void)testThatTrackerEndsRequestWhenDownloadTaskCancelled
{
    [self setupStubsWithStatusCode:200];
    
    NSURLSessionDownloadTask *downloadTask = [_session downloadTaskWithURL:_defaultURL];
    [downloadTask resume];
    [downloadTask cancel];
    
    [self assertThatTrackerEndsRequestForSessionTask:downloadTask];
}

- (void)testThatTrackerEndsRequestWhenDownloadTaskErrorOccurred
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:self.defaultURLString];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithError:[NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil]];
    }];
    
    NSURLSessionDownloadTask *downloadTask = [_session downloadTaskWithURL:_defaultURL];
    [downloadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:downloadTask];
}

#pragma mark - NSURLSessionUploadTask tests

- (void)testThatTrackerStartsRequestWhenUploadTaskResumed
{
    [self setupStubsWithStatusCode:201];
    
    NSURLSessionUploadTask *uploadTask = [_session uploadTaskWithRequest:[NSURLRequest requestWithURL:_defaultURL] fromData:[@"Some data" dataUsingEncoding:NSUTF8StringEncoding]];
    [uploadTask resume];
    
    OCMVerify([_trackerMock startRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURLRequest *request = (NSURLRequest *)obj;
        return  [request isKindOfClass:NSURLRequest.class] &&
        [request isEqual:uploadTask.originalRequest] &&
        [request.URL.absoluteString isEqualToString:self.defaultURLString];
    }]]);
}

- (void)testThatTrackerDoesNotStartRequestWhenUploadTaskCreated
{
    [self setupStubsWithStatusCode:201];
    
    OCMStub([_trackerMock startRequest:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        XCTFail(@"startRequest should not be called");
    });
    
    [_session uploadTaskWithRequest:[NSURLRequest requestWithURL:_defaultURL] fromData:[@"Some data" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)testThatTrackerEndsRequestWhenUploadTaskCompleted
{
    [self setupStubsWithStatusCode:201];
    
    NSURLSessionUploadTask *uploadTask = [_session uploadTaskWithRequest:[NSURLRequest requestWithURL:_defaultURL] fromData:[@"Some data" dataUsingEncoding:NSUTF8StringEncoding]];
    [uploadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:uploadTask statusCode:201];
}

- (void)testThatTrackerEndsRequestWhenUploadTaskHasCompletionHandler
{
    [self setupStubsWithStatusCode:201];
    
    NSURLSessionUploadTask *uploadTask = [_session uploadTaskWithRequest:[NSURLRequest requestWithURL:_defaultURL] fromData:[@"Some data" dataUsingEncoding:NSUTF8StringEncoding] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssert(data.length);
        XCTAssertNotNil(response);
    }];
    [uploadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:uploadTask statusCode:201];
}

- (void)testThatTrackerEndsRequestWhenUploadTaskHasDelegate
{
    [self setupStubsWithStatusCode:201];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:[NSURLRequest requestWithURL:_defaultURL] fromData:[@"Some data" dataUsingEncoding:NSUTF8StringEncoding]];
    [uploadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:uploadTask statusCode:201];
    XCTAssert(_taskCompleteDelegateCalled);
    [session invalidateAndCancel];
}

- (void)testThatTrackerEndsRequestWhenUploadTaskFailed
{
    [self setupStubsWithStatusCode:500]; // Internal server error
    
    NSURLSessionUploadTask *uploadTask = [_session uploadTaskWithRequest:[NSURLRequest requestWithURL:_defaultURL] fromData:[@"Some data" dataUsingEncoding:NSUTF8StringEncoding]];
    [uploadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:uploadTask statusCode:500];
}

- (void)testThatTrackerEndsRequestWhenUploadTaskCancelled
{
    [self setupStubsWithStatusCode:201];
    
    NSURLSessionUploadTask *uploadTask = [_session uploadTaskWithRequest:[NSURLRequest requestWithURL:_defaultURL] fromData:[@"Some data" dataUsingEncoding:NSUTF8StringEncoding]];
    [uploadTask resume];
    [uploadTask cancel];
    
    [self assertThatTrackerEndsRequestForSessionTask:uploadTask];
}

- (void)testThatTrackerEndsRequestWhenUploadTaskErrorOccurred
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:self.defaultURLString];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithError:[NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil]];
    }];
    
    NSURLSessionUploadTask *uploadTask = [_session uploadTaskWithRequest:[NSURLRequest requestWithURL:_defaultURL] fromData:[@"Some data" dataUsingEncoding:NSUTF8StringEncoding]];
    [uploadTask resume];
    
    [self assertThatTrackerEndsRequestForSessionTask:uploadTask];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
    _taskCompleteDelegateCalled = YES;
}

#pragma mark - Helpers

- (void)setupStubsWithStatusCode:(int)statusCode
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:self.defaultURLString];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [[OHHTTPStubsResponse responseWithData:[@"Some data" dataUsingEncoding:NSUTF8StringEncoding] statusCode:statusCode headers:nil] responseTime:0.2];
    }];
}

- (void)assertThatTrackerEndsRequestForSessionTask:(NSURLSessionTask *)dataTask
{
    [self assertThatTrackerEndsRequestForSessionTask:dataTask statusCode:0];
}

- (void)assertThatTrackerEndsRequestForSessionTask:(NSURLSessionTask *)dataTask statusCode:(NSInteger)statusCode
{
    XCTestExpectation *wait = [self expectationWithDescription:@"wait"];

    // Need to wait at least 'responseTime' for OHHTTPStubs response
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        uint_fast64_t ti = [objc_getAssociatedObject(dataTask, @selector(_rpt_sessionTask_trackingIdentifier)) unsignedLongLongValue];
        XCTAssertNotEqual(ti, 0);

        OCMVerify([self.trackerMock updateStatusCode:statusCode trackingIdentifier:ti]);
        OCMVerify([self.trackerMock end:ti]);

        _RPTMeasurement *measurement = [_trackingManager.ringBuffer measurementWithTrackingIdentifier:ti];
        XCTAssertNotNil(measurement);
        XCTAssertEqual(measurement.statusCode, statusCode);
        XCTAssert(measurement.endTime > measurement.startTime);
        [wait fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
