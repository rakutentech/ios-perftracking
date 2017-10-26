#import "_RPTRingBuffer.h"
#import "_RPTMeasurement.h"
#import <stdatomic.h>

@interface _RPTRingBuffer () {
    atomic_uint_fast64_t _nextTrackingId;
}
@property (nonatomic) NSArray<_RPTMeasurement *> *measurements;
@end

/* RPT_EXPORT */ @implementation _RPTRingBuffer
- (instancetype)init NS_UNAVAILABLE
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithSize:(NSUInteger)size
{
    if ((self = [super init]))
    {
        if (!size) return nil;
        _size = size;

        NSMutableArray *builder = [NSMutableArray arrayWithCapacity:_size];
        for (NSUInteger index = 0; index < _size; ++index)
        {
            [builder addObject:[_RPTMeasurement new]];
        }

        _measurements = builder.copy;
        if (!_measurements) return nil;

    }
    return self;
}

- (_RPTMeasurement *)measurementAtIndex:(NSUInteger)index
{
    return index >= _size ? nil : _measurements[index];
}

- (_RPTMeasurement *)measurementWithTrackingIdentifier:(uint_fast64_t)trackingIdentifier
{
    if (trackingIdentifier)
    {
        _RPTMeasurement *measurement = _measurements[trackingIdentifier % _size];
        if (measurement.trackingIdentifier == trackingIdentifier) return measurement;
    }
    return nil;
}

- (_RPTMeasurement *)nextMeasurement
{
    /*
     * Get next tracking identifier
     */
    uint_fast64_t trackingIdentifier = atomic_fetch_add_explicit(&_nextTrackingId, 1, memory_order_relaxed);
    if (!trackingIdentifier)
    {
        trackingIdentifier = atomic_fetch_add_explicit(&_nextTrackingId, 1, memory_order_relaxed);
    }

    _RPTMeasurement *measurement = _measurements[trackingIdentifier % _size];

    if (measurement.trackingIdentifier)
    {
        /*
         * Ring buffer is full, so we undo the last operation on _nextTrackingId and return nil.
         */

        // FIXME : fix "Value stored to 'trackingIdentifier' is never read" warning, then remove pragma
        #pragma unused(trackingIdentifier)
        trackingIdentifier = atomic_fetch_sub_explicit(&_nextTrackingId, 1, memory_order_relaxed);
        return nil;
    }

    measurement.trackingIdentifier = trackingIdentifier;
    return measurement;
}
@end
