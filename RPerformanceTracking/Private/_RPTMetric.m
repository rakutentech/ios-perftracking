#import "_RPTMetric.h"

const NSTimeInterval _RPT_METRIC_MAXTIME = 10.0;

/* RPT_EXPORT */ @implementation _RPTMetric

- (NSUInteger)hash
{
    return self.identifier.hash ^ [@(self.startTime) hash] ^ [@(self.endTime) hash] ^ [@(self.urlCount) hash];
}


//FIXME : fix "-Wnullable-to-nonnull-conversion" warning, then remove pragma
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
- (BOOL)isEqual:(_RPTMetric *)other
{
    // Only the identifier and the object participate in equality testing
    if (self == other) return YES;

    if (![other isMemberOfClass:self.class]) return NO;

    return
    ((!self.identifier && !other.identifier) || (self.identifier && other.identifier && [self.identifier isEqualToString:other.identifier]))
    && (self.startTime == other.startTime)
    && (self.endTime == other.endTime)
    && (self.urlCount == other.urlCount);
}
#pragma clang diagnostic pop

- (instancetype)copyWithZone:(NSZone *)zone
{
    _RPTMetric *copy = [[self.class allocWithZone:zone] init];
    copy.identifier = self.identifier;
    copy.startTime = self.startTime;
    copy.endTime = self.endTime;
    copy.urlCount = self.urlCount;
    return copy;
}

@end
