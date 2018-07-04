#import <Kiwi/Kiwi.h>
#import "_RPTRingBuffer.h"
#import "_RPTMeasurement.h"

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

    describe(@"retrieve measurement", ^{

        __block _RPTRingBuffer *buffer = nil;
        NSUInteger size = 10;

        beforeAll(^{
            NSMutableArray *builder = [NSMutableArray arrayWithCapacity:size];
            for (NSUInteger index = 0; index < size; ++index)
            {
                _RPTMeasurement *measurement = [_RPTMeasurement new];
                measurement.trackingIdentifier = index;
                [builder addObject:measurement];
            }

            buffer = [[_RPTRingBuffer alloc] initWithSize:size];
            buffer.measurements = builder.copy;
        });

        context(@"measurementAtIndex", ^{

            it(@"should return a non-nil measurement when the passed index is less than the buffer's size", ^{
                NSUInteger validIndex = size-1;
                _RPTMeasurement *measurement = [buffer measurementAtIndex:validIndex];
                [[measurement should] beNonNil];
            });

            it(@"should return a measurement having the same tracking identifier as expected", ^{
                NSUInteger validIndex = size-1;
                _RPTMeasurement *measurement = [buffer measurementAtIndex:validIndex];
                [[theValue(measurement.trackingIdentifier) should] equal:theValue(validIndex)];
            });

            it(@"should return a nil measurement when the passed index is bigger than the buffer's size", ^{
                _RPTMeasurement *measurement = [buffer measurementAtIndex:size + 1];
                [[measurement should] beNil];
            });

            it(@"should return a nil measurement when the passed index is equal to the buffer's size", ^{
                _RPTMeasurement *measurement = [buffer measurementAtIndex:size];
                [[measurement should] beNil];
            });
        });

        context(@"measurementWithTrackingIdentifier", ^{

            it(@"should return a non-nil measurement when the passed an index is less than the buffer's size", ^{
                NSUInteger validIndex = size-1;
                _RPTMeasurement *measurement = [buffer measurementWithTrackingIdentifier:validIndex];
                [[measurement should] beNonNil];
            });

            it(@"should return a measurement having the same tracking identifier as expected", ^{
                NSUInteger validIndex = size-1;
                _RPTMeasurement *measurement = [buffer measurementWithTrackingIdentifier:validIndex];
                [[theValue(measurement.trackingIdentifier) should] equal:theValue(validIndex)];
            });

            it(@"should return a nil measurement when the passed index is bigger than the buffer's size", ^{
                _RPTMeasurement *measurement = [buffer measurementWithTrackingIdentifier:size + 1];
                [[measurement should] beNil];
            });

            it(@"should return a nil measurement when the passed index is equal to the buffer's size", ^{
                _RPTMeasurement *measurement = [buffer measurementWithTrackingIdentifier:size];
                [[measurement should] beNil];
            });
        });
    });

    describe(@"nextMeasurement", ^{

        it(@"should return a non-nil measurement when the buffer is not full", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];
            _RPTMeasurement *measurement = nil;
            for (int i = 0; i < 5; i++) {
                measurement = [buffer nextMeasurement];
            }
            [[measurement should] beNonNil];
            [[theValue(measurement.trackingIdentifier) should] equal:theValue(5)];
        });

        it(@"should return a nil measurement when the buffer is full", ^{
            _RPTRingBuffer *buffer = [[_RPTRingBuffer alloc] initWithSize:10];
            _RPTMeasurement *measurement = nil;
            for (int i = 0; i < 11; i++) {
                measurement = [buffer nextMeasurement];
            }
            [[measurement should] beNil];
        });
    });
});

SPEC_END
