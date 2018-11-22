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

    describe(@"_RPTNumberToBool", ^{
        context(@"input is nil", ^{
            it(@"should be false if default value is NO", ^{
                BOOL output = _RPTNumberToBool(nil, NO);

                [[theValue(output) should] beFalse];
            });

            it(@"should be true if default value is YES", ^{
                BOOL output = _RPTNumberToBool(nil, YES);

                [[theValue(output) should] beTrue];
            });
        });

        context(@"input is not a number", ^{
            it(@"should be false if default value is NO", ^{
                BOOL output = _RPTNumberToBool(@"123", NO);

                [[theValue(output) should] beFalse];
            });

            it(@"should be true if default value is YES", ^{
                BOOL output = _RPTNumberToBool(@"123", YES);

                [[theValue(output) should] beTrue];
            });
        });

        context(@"input is 1", ^{
            it(@"should be true even default value is NO", ^{
                BOOL output = _RPTNumberToBool(@(1), NO);

                [[theValue(output) should] beTrue];
            });

            it(@"should be true when default value YES", ^{
                BOOL output = _RPTNumberToBool(@(1), YES);

                [[theValue(output) should] beTrue];
            });
        });

        context(@"input is a number not 0", ^{
            it(@"should be true even default value is NO", ^{
                BOOL output = _RPTNumberToBool(@(5), NO);

                [[theValue(output) should] beTrue];
            });

            it(@"should be true when default value YES", ^{
                BOOL output = _RPTNumberToBool(@(5), YES);

                [[theValue(output) should] beTrue];
            });
        });

        context(@"input is 0", ^{
            it(@"should be false even default value is YES", ^{
                BOOL output = _RPTNumberToBool(@(0), YES);

                [[theValue(output) should] beFalse];
            });

            it(@"should be false when default value is NO", ^{
                BOOL output = _RPTNumberToBool(@(0), NO);

                [[theValue(output) should] beFalse];
            });
        });
    });
});

SPEC_END
