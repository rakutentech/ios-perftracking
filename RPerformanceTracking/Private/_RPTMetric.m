#import "_RPTMetric.h"
#import "_RPTEnvironment.h"

const NSTimeInterval _RPT_METRIC_MAXTIME = 10.0;

/* RPT_EXPORT */ @implementation _RPTMetric

- (NSUInteger)hash {
    return self.identifier.hash ^ [@(self.startTime) hash] ^ [@(self.endTime) hash] ^ [@(self.urlCount) hash];
}

- (BOOL)isEqual:(_RPTMetric *)other {
    // Only the identifier and the object participate in equality testing
    if (self == other)
        return YES;

    if (![other isMemberOfClass:self.class])
        return NO;

    NSString *ownId = self.identifier;
    NSString *otherId = other.identifier;

    return ((!ownId && !otherId) || (ownId && otherId && [ownId isEqualToString:otherId])) && (self.startTime == other.startTime) && (self.endTime == other.endTime) && (self.urlCount == other.urlCount);
}

- (instancetype)copyWithZone:(NSZone *)zone {
    _RPTMetric *copy = [[self.class allocWithZone:zone] init];
    copy.identifier = self.identifier;
    copy.startTime = self.startTime;
    copy.endTime = self.endTime;
    copy.urlCount = self.urlCount;
    return copy;
}

- (BOOL)durationLessThanMax {
    NSTimeInterval duration = _endTime - _startTime;
    return duration < [self.class maxDurationInSecs];
}

+ (NSTimeInterval)maxDurationInSecs {
    _RPTEnvironment *env = _RPTEnvironment.new;
    return env.maximumMetricDurationSeconds > 0 ? env.maximumMetricDurationSeconds : _RPT_METRIC_MAXTIME;
}

@end
