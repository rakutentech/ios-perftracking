#import <Kiwi/Kiwi.h>
#import "_RPTEventBroadcast.h"

SPEC_BEGIN(RPTEventBroadcastTests)

describe(@"RPTEventBroadcast", ^{
    describe(@"sendEventName:topLevelDataObject", ^{
        context(@"eventName", ^{
            it(@"should not post a notification if name is nil", ^{
                [[@"com.rakuten.esd.sdk.events.custom" shouldNot] bePosted];

                [_RPTEventBroadcast sendEventName:nil topLevelDataObject:@{@"foo": @"bar"}];
            });

            it(@"should not post a notification if name is empty", ^{
                [[@"com.rakuten.esd.sdk.events.custom" shouldNot] bePosted];

                [_RPTEventBroadcast sendEventName:@"" topLevelDataObject:@{@"foo": @"bar"}];
            });

            it(@"should post a notification if name is not nil", ^{
                [[@"com.rakuten.esd.sdk.events.custom" should] bePosted];

                [_RPTEventBroadcast sendEventName:@"custom" topLevelDataObject:@{@"foo": @"bar"}];
            });
        });

        context(@"topLevelObject", ^{
            __block NSNotificationCenter* notificationCenter;
            beforeEach(^{
                notificationCenter = [NSNotificationCenter nullMock];
                [NSNotificationCenter stub:@selector(defaultCenter) andReturn:notificationCenter];
            });

            it(@"should post a notification with object.eventName is equal to passed value", ^{
                KWCaptureSpy *spy = [notificationCenter captureArgument:@selector(postNotificationName:object:) atIndex:1];

                [_RPTEventBroadcast sendEventName:@"custom" topLevelDataObject:@{}];

                NSDictionary *dict = spy.argument;
                [[dict[@"eventName"] should] equal:@"custom"];
            });

            it(@"should post a notification with object.topLevelObject is equal to passed value", ^{
                KWCaptureSpy *spy = [notificationCenter captureArgument:@selector(postNotificationName:object:) atIndex:1];
                [_RPTEventBroadcast sendEventName:@"custom" topLevelDataObject:@{@"foo": @"bar"}];

                NSDictionary *dict = spy.argument;
                [[dict[@"topLevelObject"] should] equal:@{@"foo": @"bar"}];
            });

            it(@"should post a notification with object.topLevelObject is nil if topLevelObject is empty", ^{
                KWCaptureSpy *spy = [notificationCenter captureArgument:@selector(postNotificationName:object:) atIndex:1];
                [_RPTEventBroadcast sendEventName:@"custom" topLevelDataObject:@{}];

                NSDictionary *dict = spy.argument;
                [[dict[@"topLevelObject"] should] beNil];
            });

            it(@"should post a notification with object.topLevelObject is nil if topLevelObject is nil", ^{
                KWCaptureSpy *spy = [notificationCenter captureArgument:@selector(postNotificationName:object:) atIndex:1];
                [_RPTEventBroadcast sendEventName:@"custom" topLevelDataObject:nil];

                NSDictionary *dict = spy.argument;
                [[dict[@"topLevelObject"] should] beNil];
            });
        });
    });
});

SPEC_END
