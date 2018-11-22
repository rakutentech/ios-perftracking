@import OCMock;
#import <XCTest/XCTest.h>
#import "TestViewController.h"
#import "_RPTRingBuffer.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTMetric.h"
#import "_RPTRingBuffer.h"
#import "_RPTSender.h"
#import "TestUtils.h"

static const NSUInteger      MAX_MEASUREMENTS    = 512u;

@interface _RPTTrackingManager()
@property (nonatomic) _RPTTracker    *tracker;
@property (nonatomic) _RPTRingBuffer *ringBuffer;
- (instancetype)init;
@end

@interface UIViewControllerTests : XCTestCase
@property (nonatomic) UIViewController *presentingViewController;
@property (nonatomic) UIStoryboard *mainStoryboard;
@property (nonatomic) NSBundle *testBundle;
@end

@implementation UIViewControllerTests

static _RPTTrackingManager *_trackingManager = nil;

+ (void)setUp
{
    [super setUp];
	_RPTRingBuffer *ringBuffer               = [_RPTRingBuffer.alloc initWithSize:MAX_MEASUREMENTS];
	_trackingManager                         = [_RPTTrackingManager sharedInstance];
	_trackingManager.ringBuffer              = ringBuffer;
    _RPTConfiguration *config               = mkConfigurationStub(nil);
    _trackingManager.tracker                = [[_RPTTracker alloc] initWithRingBuffer:ringBuffer
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
    [super setUp];
    _testBundle = [NSBundle bundleForClass:self.class];
    _mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:_testBundle];
    _presentingViewController = [_mainStoryboard instantiateViewControllerWithIdentifier:@"PresentingViewController"];
}

- (void)tearDown
{
    _testBundle = nil;
    _mainStoryboard = nil;
    _presentingViewController = nil;
    [super tearDown];
}

- (void)testLoadViewMethodIsCalledWhenViewControllerIsCreatedWithIdentifierFromStoryboard
{
    UIViewController *presentedVC = [_mainStoryboard instantiateViewControllerWithIdentifier:@"PresentedViewController"];
    id mockVC = OCMPartialMock(presentedVC);
    [_presentingViewController presentViewController:presentedVC animated:YES completion:nil];
    OCMVerify([mockVC loadView]);
    [mockVC stopMocking];
}

- (void)testViewDidLoadMethodIsCalledWhenViewControllerIsCreatedWithIdentifierFromStoryboard
{
    UIViewController *presentedVC = [_mainStoryboard instantiateViewControllerWithIdentifier:@"PresentedViewController"];
    id mockVC = OCMPartialMock(presentedVC);
    [_presentingViewController presentViewController:presentedVC animated:YES completion:nil];
    OCMVerify([mockVC viewDidLoad]);
    [mockVC stopMocking];
}

- (void)testLoadViewMethodIsCalledWhenViewControllerIsInitWithNibName
{
    UIViewController *presentedVC = [[TestViewController alloc] initWithNibName:@"TestViewController" bundle:_testBundle];
    id mockVC = OCMPartialMock(presentedVC);
    [_presentingViewController presentViewController:presentedVC animated:YES completion:nil];
    OCMVerify([mockVC loadView]);
    [mockVC stopMocking];
}

- (void)testViewDidLoadMethodIsCalledWhenViewControllerIsInitWithNibName
{
    UIViewController *presentedVC = [[TestViewController alloc] initWithNibName:@"TestViewController" bundle:_testBundle];
    id mockVC = OCMPartialMock(presentedVC);
    [_presentingViewController presentViewController:presentedVC animated:YES completion:nil];
    OCMVerify([mockVC viewDidLoad]);
    [mockVC stopMocking];
}

- (void)testProlongMethodIsCalledWhenViewWillAppear
{
    id trackerMock = OCMPartialMock(_trackingManager.tracker);
    UIViewController *presentedVC = [[TestViewController alloc] initWithNibName:@"TestViewController" bundle:_testBundle];
    [presentedVC viewWillAppear:NO];
    OCMVerify([trackerMock prolongMetric]);
    [trackerMock stopMocking];
}

- (void)testScreenNameUpdatedToCurrentViewController
{
    UIViewController *presentedVC = [[TestViewController alloc] initWithNibName:@"TestViewController" bundle:_testBundle];
    [presentedVC viewWillAppear:YES];
    XCTAssertNotNil(_trackingManager.currentScreen);
    XCTAssertEqualObjects(@"TestViewController", _trackingManager.currentScreen);
}

@end
