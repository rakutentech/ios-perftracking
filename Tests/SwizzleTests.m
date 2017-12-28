@import XCTest;
#import <OCMock/OCMock.h>
#import "_RPTClassManipulator.h"

@interface _RPTClassManipulator ()
+ (void)_removeSwizzleSelector:(SEL)sel onClass:(Class)recipient types:(const char *)types;
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
#pragma clang diagnostic pop
@end
