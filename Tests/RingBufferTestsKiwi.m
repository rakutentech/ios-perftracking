#import <Kiwi/Kiwi.h>
#import "_RPTRingBuffer.h"
#import "_RPTMeasurement.h"
#import "TestUtils.h"

@interface _RPTRingBuffer ()
@property (nonatomic) NSArray<_RPTMeasurement *> *measurements;
@end

SPEC_BEGIN(RingBufferTestsKiwi)

describe(@"RingBuffer", ^{

    describe(@"init", ^{

        it(@"should be non-nil when initialized with non-zero size", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:12];

            [[buffer should] beNonNil];
        });

        it(@"should have same size with size passed in parameter", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:12];
            
            [[buffer.measurements should] haveLengthOf:12];
        });

        it(@"should set the size with the value passed in parameter", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:12];

            [[theValue(buffer.size) should] equal:theValue(12)];
        });

        it(@"should be nil when initialized with zero size", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:0];

            [[buffer should] beNil];
        });

    });

    describe(@"measurementAtIndex", ^{

        it(@"should return a non-nil measurement when the passed index is less than the buffer's size", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];

            _RPTMeasurement *measurement = [buffer measurementAtIndex:5];

            [[measurement should] beNonNil];
        });

        it(@"should return a nil measurement when the passed index is bigger than the buffer's size", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];

            _RPTMeasurement *measurement = [buffer measurementAtIndex:11];

            [[measurement should] beNil];
        });

        it(@"should return a nil measurement when the passed index is equal to the buffer's size", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];

            _RPTMeasurement *measurement = [buffer measurementAtIndex:10];

            [[measurement should] beNil];
        });
    });

    describe(@"measurementWithTrackingIdentifier", ^{

        it(@"should return a non-nil measurement when the passed tracking identifier is in the filled range", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];
            mkFillBuffer(buffer, 5, 9);

            _RPTMeasurement *measurement = [buffer measurementWithTrackingIdentifier:6];

            [[measurement should] beNonNil];
        });

        it(@"should return a measurement having the same tracking identifier as expected when the passed tracking identifier is in the filled range", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];
            mkFillBuffer(buffer, 5, 9);

            _RPTMeasurement *measurement = [buffer measurementWithTrackingIdentifier:6];

            [[theValue(measurement.trackingIdentifier) should] equal:theValue(6)];
        });

        it(@"should return a nil measurement when the passed tracking identifier is not in the filled range", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];
            mkFillBuffer(buffer, 5, 9);

            _RPTMeasurement *measurement = [buffer measurementWithTrackingIdentifier:2];

            [[measurement should] beNil];
        });
    });

    describe(@"nextMeasurement", ^{

        it(@"should return a non-nil measurement when the buffer is not full", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];
            mkFillBuffer(buffer, 5, 10);

            _RPTMeasurement *measurement = [buffer nextMeasurement];

            [[measurement should] beNonNil];
        });

        it(@"should return a non-nil measurement with tracking identifier set to 11 when the buffer is not full and the tracking identifiers up to 10 have been used", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];
            mkFillBuffer(buffer, 5, 10);

            _RPTMeasurement *measurement = [buffer nextMeasurement];

            [[theValue(measurement.trackingIdentifier) should] equal:theValue(11)];
        });

        it(@"should return a nil measurement when the buffer is full", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];
            mkFillBuffer(buffer, 0, 10);

            _RPTMeasurement *measurement = [buffer nextMeasurement];

            [[measurement should] beNil];
        });
    });
});

SPEC_END
