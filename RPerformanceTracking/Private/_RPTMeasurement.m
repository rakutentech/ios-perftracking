#import "_RPTMeasurement.h"

const NSTimeInterval _RPT_MEASUREMENT_MAXTIME = 30.0;

/* RPT_EXPORT */ @implementation _RPTMeasurement
- (instancetype)init {
    if (self = [super init]) {
        _endTime = [NSDate.distantPast timeIntervalSinceDate:NSDate.date];
        _statusCode = 0;
    }
    return self;
}

- (void)clear {
    _kind = 0;
    _trackingIdentifier = 0ull;
    _startTime = 0;
    _endTime = [NSDate.distantPast timeIntervalSinceDate:NSDate.date];
    _receiver = nil;
    _method = nil;
    _screen = nil;
    _statusCode = 0;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Measurement<%p>: kind %lu trackingId %llu startTime %f endTime %f receiver %@ method %@ screen %@ statusCode %ld", self, (unsigned long)_kind, (unsigned long long)_trackingIdentifier, _startTime, _endTime, _receiver, _method, _screen, (long)_statusCode];
}
@end
