#import <Kiwi/Kiwi.h>
#import "_RPTHelpers.h"

SPEC_BEGIN(RPTHelpersTests)

describe(@"RPTHelpers", ^{
    describe(@"_RPTTimeIntervalInMiliseconds", ^{
        it(@"should be 0 when the input is less than 0", ^{
            NSTimeInterval timeInterval = -12.3456;

            uint64_t output = _RPTTimeIntervalInMiliseconds(timeInterval);

            [[theValue(output) should] equal:theValue(0)];
        });

        it(@"should be equal the integer part of 1000 times of the input", ^{
            NSTimeInterval timeInterval = 12.3456;

            uint64_t output = _RPTTimeIntervalInMiliseconds(timeInterval);

            [[theValue(output) should] equal:theValue(12345)];
        });
    });
});

SPEC_END
