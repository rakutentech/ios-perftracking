#import <Kiwi/Kiwi.h>
#import "_RPTMetric.h"

SPEC_BEGIN(RPTMetricTests)

describe(@"RPTMetric", ^{
    describe(@"maxDurationInSecs", ^{
        it(@"should return value 10.0", ^{
            NSTimeInterval max = [_RPTMetric maxDurationInSecs];
            
            [[theValue(max) should] equal:theValue(10.0)];
        });
    });
    
    describe(@"durationLessThanMax", ^{
        __block _RPTMetric *metric = _RPTMetric.new;
        metric.identifier = @"identifier";
        metric.urlCount = 0;
        
        it(@"should return true when duration < max", ^{
            NSTimeInterval now = [NSDate.date timeIntervalSince1970];
            metric.startTime = now - 5.0; // 5 secs in past
            metric.endTime = now;
            
            [[theValue([metric durationLessThanMax]) should] beTrue];
        });
        
        it(@"should return false when duration > max", ^{
            NSTimeInterval now = [NSDate.date timeIntervalSince1970];
            metric.startTime = now - 5.0;
            metric.endTime = now + 10.0;
            
            [[theValue([metric durationLessThanMax]) should] beFalse];
        });
        
        it(@"should return false when duration == max", ^{
            NSTimeInterval now = [NSDate.date timeIntervalSince1970];
            metric.startTime = now;
            metric.endTime = now + 10.0;
            
            [[theValue([metric durationLessThanMax]) should] beFalse];
        });
    });
    
    // TODO: Tests for isEqual and copy
});

SPEC_END
