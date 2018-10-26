@import XCTest;
#import <OCMock/OCMock.h>
#import <Kiwi/Kiwi.h>
#import "_RPTClassManipulator.h"
#import "_RPTClassManipulator+NSURLSessionTask.h"

@interface _RPTClassManipulator ()
+ (void)_removeSwizzleSelector:(SEL)sel onClass:(Class)recipient types:(const char *)types;
@end

@interface Parent : NSObject
@property (nonatomic) int count;
- (void)noOverrideMethod;
- (void)overrideAndCallSuperMethod;
- (void)overrideWithoutCallingSuperMethod;
@end

@implementation Parent
- (instancetype)init
{
    if ((self = [super init]))
    {
        _count = 0;
    }
    return self;
}

- (void)noOverrideMethod
{
    _count ++;
}

- (void)overrideAndCallSuperMethod
{
    _count ++;
}

- (void)overrideWithoutCallingSuperMethod
{
    _count ++;
}
@end

@interface Child : Parent
@end

@implementation Child
- (void)overrideAndCallSuperMethod
{
    [super overrideAndCallSuperMethod];
    self.count ++;
}

- (void)overrideWithoutCallingSuperMethod
{
    self.count ++;
}
@end

@interface SwizzleTests : XCTestCase
@property (nonatomic) BOOL originalCalled;
@property (nonatomic) BOOL swizzleCalled;
@end

@implementation SwizzleTests

- (void)setUp
{
    _originalCalled = NO;
    _swizzleCalled = NO;
}

- (void)aMethodWithParam1:(id)param1 param2:(NSString *)param2 param3:(NSInteger)param3
{
    _originalCalled = YES;
    
    // Ensure parameters are being passed correctly from swizzle IMP
    XCTAssert([param1 isKindOfClass:NSValue.class]);
    XCTAssert([param2 isKindOfClass:NSString.class]);
    XCTAssert(param3 == 5);
}

- (void)setupSwizzleHasOriginalMethod
{
    id swizzle_blockImp = ^(id<NSObject> selfRef, id param1, NSString *param2, NSInteger param3) {
        
        XCTAssert([param1 isKindOfClass:NSValue.class]);
        XCTAssert([param2 isKindOfClass:NSString.class]);
        XCTAssert(param3 == 5);
        
        self.swizzleCalled = YES;
        
        SEL selector = @selector(aMethodWithParam1:param2:param3:);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            ((void(*)(id, SEL, id, id, NSInteger))originalImp)(selfRef, selector, param1, param2, param3);
        }
    };
    [_RPTClassManipulator swizzleSelector:@selector(aMethodWithParam1:param2:param3:)
                                  onClass:self.class
                        newImplementation:imp_implementationWithBlock(swizzle_blockImp)
                                    types:"v@:@@i"];
}

- (void)removeSwizzleHasOriginalMethod
{
    [_RPTClassManipulator _removeSwizzleSelector:@selector(aMethodWithParam1:param2:param3:)
                                         onClass:self.class
                                           types:"v@:@@i"];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
- (void)setupSwizzleNoOriginalMethod
{
    id swizzle_blockImp = ^(id<NSObject> selfRef, id param1) {
        self.swizzleCalled = YES;
    };

    [_RPTClassManipulator swizzleSelector:@selector(aMethodThatDoesntExist:)
                                  onClass:self.class
                        newImplementation:imp_implementationWithBlock(swizzle_blockImp)
                                    types:"v@:@"];
}

- (void)testThatSwizzleIsCalled
{
    [self setupSwizzleHasOriginalMethod];
    [self aMethodWithParam1:[NSValue valueWithCGRect:CGRectZero] param2:@"test" param3:5];
    XCTAssert(_swizzleCalled);
    [self removeSwizzleHasOriginalMethod];
}

- (void)testThatOriginalMethodIsCalled
{
    [self setupSwizzleHasOriginalMethod];
    [self aMethodWithParam1:[NSValue valueWithCGRect:CGRectZero] param2:@"test" param3:5];
    XCTAssert(_originalCalled);
    [self removeSwizzleHasOriginalMethod];
}

- (void)testThatSwizzleCanBeRemoved
{
    [self setupSwizzleHasOriginalMethod];
    [self removeSwizzleHasOriginalMethod];
    [self aMethodWithParam1:[NSValue valueWithCGRect:CGRectZero] param2:@"test" param3:5];
    XCTAssert(!_swizzleCalled);
}

- (void)testThatOriginalIsCalledAfterSwizzleRemoved
{
    [self setupSwizzleHasOriginalMethod];
    [self removeSwizzleHasOriginalMethod];
    [self aMethodWithParam1:[NSValue valueWithCGRect:CGRectZero] param2:@"test" param3:5];
    XCTAssert(_originalCalled);
}

- (void)testThatSwizzleIsCalledWhenNoOriginalMethod
{
    [self setupSwizzleNoOriginalMethod];
    [self performSelector:@selector(aMethodThatDoesntExist:) withObject:@1];
    XCTAssert(_swizzleCalled);
}

- (void)testThatSwizzleBlockAndOriginalMethodInParentClassAreCalled
{
    id swizzle_blockImp = ^(Parent *selfRef) {
        selfRef.count ++;
        SEL selector = @selector(noOverrideMethod);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:Parent.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL))originalImp)(selfRef, selector);
        }
    };
    [_RPTClassManipulator swizzleSelector:@selector(noOverrideMethod)
                                  onClass:Parent.class
                        newImplementation:imp_implementationWithBlock(swizzle_blockImp)
                                    types:"v@:"];
    Child *child = [[Child alloc] init];
    XCTAssertEqual(child.count, 0);
    [child noOverrideMethod];
    /*
     * Verify that count is increased twice (once in swizzle block, once in original method in Parent class).
     */
    XCTAssertEqual(child.count, 2);
}

- (void)testThatSwizzleBlockAndOriginalMethodInParentClassAndOverrideMethodInChildClassAreCalled
{
    id swizzle_blockImp = ^(Parent *selfRef) {
        selfRef.count ++;
        SEL selector = @selector(overrideAndCallSuperMethod);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:Parent.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL))originalImp)(selfRef, selector);
        }
    };
    [_RPTClassManipulator swizzleSelector:@selector(overrideAndCallSuperMethod)
                                  onClass:Parent.class
                        newImplementation:imp_implementationWithBlock(swizzle_blockImp)
                                    types:"v@:"];
    Child *child = [[Child alloc] init];
    XCTAssertEqual(child.count, 0);
    [child overrideAndCallSuperMethod];
    /*
     * Verify that count is increased three times (once in swizzle block, once in original method in Parent class and once in override method in Child class).
     */
    XCTAssertEqual(child.count, 3);
}

- (void)testThatSwizzleBlockAndOriginalMethodInParentClassAreNotCalled
{
    id swizzle_blockImp = ^(Parent *selfRef) {
        selfRef.count ++;
        SEL selector = @selector(overrideWithoutCallingSuperMethod);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:Parent.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL))originalImp)(selfRef, selector);
        }
    };
    [_RPTClassManipulator swizzleSelector:@selector(overrideWithoutCallingSuperMethod)
                                  onClass:Parent.class
                        newImplementation:imp_implementationWithBlock(swizzle_blockImp)
                                    types:"v@:"];
    Child *child = [[Child alloc] init];
    XCTAssertEqual(child.count, 0);
    [child overrideWithoutCallingSuperMethod];
    /*
     * Verify that count is increased only once in overrid method in Child class.
     */
    XCTAssertEqual(child.count, 1);
}

- (void)testThatSwizzlingParentAndChildClassDoesNotCauseOverflowCrash
{
    id swizzle_blockImp = ^(Parent *selfRef) {
        selfRef.count ++;
        SEL selector = @selector(overrideAndCallSuperMethod);
        IMP originalImp = [_RPTClassManipulator implementationForOriginalSelector:selector class:selfRef.class];
        if (originalImp)
        {
            return ((void(*)(id, SEL))originalImp)(selfRef, selector);
        }
    };
    [_RPTClassManipulator swizzleSelector:@selector(overrideAndCallSuperMethod)
                                  onClass:Parent.class
                        newImplementation:imp_implementationWithBlock(swizzle_blockImp)
                                    types:"v@:"];
    
    [_RPTClassManipulator swizzleSelector:@selector(overrideAndCallSuperMethod)
                                  onClass:Child.class
                        newImplementation:imp_implementationWithBlock(swizzle_blockImp)
                                    types:"v@:"];
    
    Child *child = [[Child alloc] init];
    XCTAssertEqual(child.count, 0);
    [child overrideAndCallSuperMethod];
    XCTAssertEqual(child.count, 3); // swizzle + parent + child
}
#pragma clang diagnostic pop
@end

SPEC_BEGIN(_RPTClassManipulatorTests)
describe(@"load", ^{
    it(@"should set up swizzles when RPTDeferSwizzlingUntilActivateResponseReceived flag is false", ^{
        [[NSBundle.mainBundle stubAndReturn:@"NO"] objectForInfoDictionaryKey:@"RPTDeferSwizzlingUntilActivateResponseReceived"];
        
        [[_RPTClassManipulator should] receive:NSSelectorFromString(@"setupSwizzles")];
        
        [_RPTClassManipulator load];
    });
    
    it(@"should not set up swizzles when RPTDeferSwizzlingUntilActivateResponseReceived flag is true", ^{
        [[NSBundle.mainBundle stubAndReturn:@"YES"] objectForInfoDictionaryKey:@"RPTDeferSwizzlingUntilActivateResponseReceived"];
        
        [[_RPTClassManipulator shouldNot] receive:NSSelectorFromString(@"setupSwizzles")];
        
        [_RPTClassManipulator load];
    });
});
describe(@"setupDeferredSwizzles", ^{
    it(@"should set up swizzles when called after deferral due to RPTDeferSwizzlingUntilActivateResponseReceived flag being set to true", ^{
        [[NSBundle.mainBundle stubAndReturn:@"YES"] objectForInfoDictionaryKey:@"RPTDeferSwizzlingUntilActivateResponseReceived"];
        [_RPTClassManipulator load];
        
        [[_RPTClassManipulator should] receive:NSSelectorFromString(@"setupSwizzles")];
        
        [_RPTClassManipulator setupDeferredSwizzles];
    });
});
SPEC_END


