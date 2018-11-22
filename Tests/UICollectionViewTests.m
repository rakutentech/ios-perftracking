@import OCMock;
#import <XCTest/XCTest.h>
#import "_RPTTracker.h"
#import "_RPTTrackingManager.h"
#import "_RPTRingBuffer.h"
#import "_RPTMetric.h"
#import "TestUtils.h"

@interface UICollectionViewCell ()
- (void)_rpt_setSelected:(BOOL)selected;
@end

@interface _RPTTrackingManager()
@property (nonatomic) _RPTTracker *tracker;
@end

@interface UICollectionViewTests : XCTestCase
@property (nonatomic) UICollectionViewCell *cell;
@end

@implementation UICollectionViewTests

static _RPTTrackingManager *_trackingManager = nil;

+ (void)setUp
{
    [super setUp];
    _trackingManager                         = [_RPTTrackingManager sharedInstance];
    _RPTConfiguration *config                = mkConfigurationStub(nil);
    _trackingManager.tracker                 = [_RPTTracker.alloc initWithRingBuffer:[_RPTRingBuffer.alloc initWithSize:512]
                                                                       configuration:config
                                                                       currentMetric:_RPTMetric.new];
}

+ (void)tearDown
{
    _trackingManager = nil;
    [super tearDown];
}

- (void)setUp
{
    [super setUp];
    _cell = [[UICollectionViewCell alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
}

- (void)tearDown
{
    _cell = nil;
    [super tearDown];
}

- (void)testOriginalMethodIsPresentInUICollectionViewCellClass
{
    XCTAssert([_cell respondsToSelector:@selector(setSelected:)]);
}

- (void)testEndMetricMethodIsCalledWhenCollectionViewCellIsSelected
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    [_cell setSelected:YES];
    OCMVerify([mockTracker endMetric]);
    [mockTracker stopMocking];
}

- (void)testEndMetricMethodIsNotCalledWhenCollectionViewCellIsUnselected
{
    id mockTracker = OCMPartialMock(_trackingManager.tracker);
    OCMStub([mockTracker endMetric]).andDo(^(NSInvocation *invocation) {
        XCTFail(@"endMetric should not be called");
    });
    [_cell setSelected:NO];
    [mockTracker stopMocking];
}
@end
