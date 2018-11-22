@import OCMock;
#import <XCTest/XCTest.h>
#import "_RPTTracker.h"
#import "_RPTTrackingManager.h"
#import "_RPTRingBuffer.h"
#import "_RPTMetric.h"
#import "_RPTSender.h"
#import "TestViewController.h"
#import "TestUtils.h"

@interface UIControl ()
- (void)_rpt_sendAction:(SEL)action to:(nullable id)target forEvent:(nullable UIEvent *)event;
@end

@interface _RPTTrackingManager()
@property (nonatomic) _RPTTracker *tracker;
- (instancetype)init;

- (void)addEndMetricObservers;
@end

/*
 * We need HostApp for these unit tests, because the events are managed by UIApplication's object.
 */

@interface UIControlTests : XCTestCase
@property (nonatomic) BOOL targetActionCalled;
@end

@implementation UIControlTests

static _RPTTrackingManager *_trackingManager = nil;

+ (void)setUp
{
    [super setUp];
    _trackingManager							= [_RPTTrackingManager sharedInstance];
    _RPTConfiguration *config                   = mkConfigurationStub(nil);
    _trackingManager.tracker					= [_RPTTracker.alloc initWithRingBuffer:[_RPTRingBuffer.alloc initWithSize:512]
                                                           configuration:config
                                                           currentMetric:_RPTMetric.new];
}

+ (void)tearDown
{
    [_trackingManager.sender stop];
    _trackingManager = nil;
    [super tearDown];
}

- (void)setUp
{
    _targetActionCalled = NO;
}

#pragma mark - UIControl's unit tests

- (void)testOriginalMethodIsPresentInClass
{
    XCTAssert([UIControl.new respondsToSelector:@selector(sendAction:to:forEvent:)]);
}

- (void)testTargetActionMethodIsCalledWhenControlEventEndsMetric
{
    [self assertThatTargetActionMethodIsCalledForEvent:UIControlEventTouchUpInside];
}

- (void)testTargetActionMethodIsCalledWhenControlEventDoesNotEndMetric
{
    [self assertThatTargetActionMethodIsCalledForEvent:UIControlEventTouchDown];
}

- (void)testEndMetricMethodIsCalledWhenControlEventIsTouchUpInside
{
    [self assertThatEndMetricIsCalledForEvent:UIControlEventTouchUpInside];
}

- (void)testEndMetricMethodIsCalledWhenControlEventIsPrimaryActionTriggered
{
    [self assertThatEndMetricIsCalledForEvent:UIControlEventPrimaryActionTriggered];
}

- (void)testEndMetricMethodIsCalledWhenTextFieldDidBeginEditing
{
    [self assertThatEndMetricIsCalledOnReceiptOfNotification:UITextFieldTextDidBeginEditingNotification];
}

- (void)testEndMetricMethodIsCalledWhenTextViewDidBeginEditing
{
    [self assertThatEndMetricIsCalledOnReceiptOfNotification:UITextViewTextDidBeginEditingNotification];
}

- (void)testEndMetricMethodIsCalledWhenControlEventIsValueChanged
{
    [self assertThatEndMetricIsCalledForEvent:UIControlEventValueChanged];
}

- (void)testEndMetricMethodIsNotCalledWhenControlEventDoesNotEndMetric
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    
    OCMStub([mockTracker endMetric]).andDo(^(NSInvocation *invocation) {
        XCTFail(@"endMetric should not be called");
    });

    UIControl *control = [UIControl.alloc init];
    [control addTarget:self action:@selector(targetActionMethod) forControlEvents:UIControlEventTouchDown];
    [control sendActionsForControlEvents:UIControlEventTouchDown];

    [mockTracker stopMocking];
}

#pragma mark - Helpers

- (void)assertThatTargetActionMethodIsCalledForEvent:(UIControlEvents)event
{
    UIControl *control = [UIControl.alloc init];
    [control addTarget:self action:@selector(targetActionMethod) forControlEvents:event];
    [control sendActionsForControlEvents:event];
    XCTAssert(_targetActionCalled);
}

- (void)assertThatEndMetricIsCalledForEvent:(UIControlEvents)event
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    
    UIControl *control = [UIControl.alloc init];
    [control addTarget:self action:@selector(targetActionMethod) forControlEvents:event];
    [control sendActionsForControlEvents:event];
    
    OCMVerify([mockTracker endMetric]);
    
    [mockTracker stopMocking];
}

- (void)assertThatEndMetricIsCalledOnReceiptOfNotification:(NSString *)notification
{
    [_trackingManager addEndMetricObservers];
    
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    
    XCTestExpectation *expectNotification = [self expectationWithDescription:@"waitForNotification"];
    
    [NSNotificationCenter.defaultCenter postNotificationName:notification object:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        OCMVerify([mockTracker endMetric]);
        [expectNotification fulfill];
    });
    
    [mockTracker stopMocking];
    
    [self waitForExpectationsWithTimeout:1.5 handler:nil];
}

- (void)targetActionMethod
{
    _targetActionCalled = YES;
}

@end
