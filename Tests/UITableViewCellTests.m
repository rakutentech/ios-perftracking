@import OCMock;
#import <XCTest/XCTest.h>
#import "_RPTTracker.h"
#import "_RPTTrackingManager.h"
#import "_RPTRingBuffer.h"
#import "_RPTMetric.h"
#import "TestUtils.h"

@interface UITableViewCell ()
- (void)_rpt_setSelected:(BOOL)selected;
@end

@interface _RPTTrackingManager()
@property (nonatomic) _RPTTracker *tracker;
@end

@interface UITableViewCellTests : XCTestCase
@property (nonatomic) UITableViewCell *cell;
@end

@implementation UITableViewCellTests
static _RPTTrackingManager *_trackingManager = nil;

+ (void)tearDown
{
    _trackingManager = nil;
    [super tearDown];
}

- (void)setUp
{
    [super setUp];
    _trackingManager                        = [_RPTTrackingManager sharedInstance];
    _RPTConfiguration *configuration        = mkConfigurationStub(nil);
    _trackingManager.tracker                 = [_RPTTracker.alloc initWithRingBuffer:[_RPTRingBuffer.alloc initWithSize:512]
                                                                       configuration:configuration
                                                                       currentMetric:_RPTMetric.new];
    _cell = [[UITableViewCell alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
}

- (void)tearDown
{
    _cell = nil;
    [super tearDown];
}

- (void)testOriginalMethodIsPresentInUITableViewCellClass
{
    XCTAssert([_cell respondsToSelector:@selector(setSelected:)]);
}

- (void)testEndMetricIsCalledWhenTableViewCellIsSelected
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_cell setSelected:YES];
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

- (void)testEndMetricIsNotCalledWhenTableViewCellIsUnselected
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    OCMStub([mockTracker endMetric]).andDo(^(NSInvocation *invocation) {
        XCTFail(@"endMetric should not be called");
    });
    [_cell setSelected:NO];
    [mockTracker stopMocking];
}

@end
