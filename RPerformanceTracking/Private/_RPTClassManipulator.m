#import <objc/runtime.h>
#import "_RPTClassManipulator.h"
#import "_RPTClassManipulator+NSURLSessionTask.h"
#import "_RPTClassManipulator+UICollectionViewCell.h"
#import "_RPTClassManipulator+UIControl.h"
#import "_RPTClassManipulator+UITableViewCell.h"
#import "_RPTClassManipulator+UIViewController.h"
#import "_RPTClassManipulator+UIWebView.h"
#import "_RPTClassManipulator+WKWebView.h"
#import "_RPTHelpers.h"

@interface SwizzleDetail : NSObject
@property (nonatomic, readonly, copy) NSString *className;
@property (nonatomic, readonly)       NSValue  *originalImplementation;

+ (instancetype)swizzleDetailWithClass:(NSString *)className implementation:(IMP)imp;
@end

@implementation SwizzleDetail
- (instancetype)initWithClass:(NSString *)className implementation:(IMP)imp
{
    if (self = [super init])
    {
        _className = className;
        _originalImplementation = [NSValue valueWithPointer:imp];
    }
    return self;
}

+ (instancetype)swizzleDetailWithClass:(NSString *)className implementation:(IMP)imp
{
    return className ? [self.alloc initWithClass:className implementation:imp] : nil;
}
@end

// Map of selectors to objects containing the class name and original implementation (or
// pointer-to-NULL if there wasn't an original)
typedef NSMutableDictionary<NSString *, SwizzleDetail *> swizzleMappingDictionary;

@interface _RPTClassManipulator ()
@property (class, nonatomic) swizzleMappingDictionary *swizzleMap;
@property (class, nonatomic) NSValue *deferredSwizzlerIMP;
@end

@implementation _RPTClassManipulator

static swizzleMappingDictionary *_swizzleMap = nil;
static NSValue *_deferredSwizzlerIMP = nil;

+ (swizzleMappingDictionary *)swizzleMap
{
    return _swizzleMap;
}

+ (void)setSwizzleMap:(swizzleMappingDictionary *)newSwizzleMap
{
    _swizzleMap = newSwizzleMap;
}

+ (NSValue *)deferredSwizzlerIMP
{
    return _deferredSwizzlerIMP;
}

+ (void)setDeferredSwizzlerIMP:(NSValue *)newDeferredSwizzlerIMP
{
    _deferredSwizzlerIMP = newDeferredSwizzlerIMP;
}

+ (void)load
{    
    if (!self.swizzleMap)
    {
        _swizzleMap = NSMutableDictionary.new;
    }
    
    if (boolForInfoPlistKey(@"RPTDeferSwizzlingUntilActivateResponseReceived"))
    {
        RPTLog(@"Defer swizzling setup until Config API response is received and tracking enabled");
        
        id setupSwizzlesBlock = ^ {
            [self setupSwizzles];
        };
        self.deferredSwizzlerIMP = [NSValue valueWithPointer:imp_implementationWithBlock(setupSwizzlesBlock)];
    }
    else
    {
        RPTLog(@"Setup swizzling at class load");
        [self setupSwizzles];
    }
}

+ (void)setupSwizzles
{
    // swizzling should only be performed once per session and on the main thread (due
    // to UI classes)
    
    void (^setupSwizzleMethodsBlock)(void) = ^ {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [_RPTClassManipulator rpt_swizzleTaskSetState];
            [_RPTClassManipulator rpt_swizzleUICollectionViewCell];
            [_RPTClassManipulator rpt_swizzleUIControl];
            [_RPTClassManipulator rpt_swizzleUITableViewCell];
            [_RPTClassManipulator rpt_swizzleUIViewController];
            [_RPTClassManipulator rpt_swizzleUIWebView];
            [_RPTClassManipulator rpt_swizzleWKWebView];
        });
    };
    
    if ([NSThread isMainThread]) {
        setupSwizzleMethodsBlock();
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            setupSwizzleMethodsBlock();
        });
    }
}

+ (void)setupDeferredSwizzles
{
    IMP imp = self.deferredSwizzlerIMP.pointerValue;
    if (!imp) { return; }
    
    void (^swizzleSetupBlock)(void) = imp_getBlock(imp);
    if (swizzleSetupBlock) { swizzleSetupBlock(); }
}

+ (Class)furthestAncestorOfRecipient:(Class)recipient implementingSelector:(SEL)sel
{
    IMP recipientMethod = [recipient methodForSelector:sel];
    Class clazz = recipient;
    Class objSuperClass = [recipient superclass];
    
    while (objSuperClass != NULL)
    {
        IMP superClassMethod = [objSuperClass instanceMethodForSelector:sel];
        if (recipientMethod &&
            superClassMethod &&
            recipientMethod != superClassMethod)
        {
            clazz = objSuperClass;
            objSuperClass = [objSuperClass superclass];
        }
        else
        {
            // IMPs are the same - we found the furthest implementor
            break;
        }
    }
    return clazz;
}

+ (void)swizzleSelector:(SEL)sel onClass:(Class)recipient newImplementation:(IMP)newImp types:(const char *)types
{
    if (!sel || !recipient || !newImp || !types)
    {
        return;
    }
    
    // If both class and superclass are swizzled on the same selector and the replacement
    // implementation is the same then we will end up in a stack overflow crash if
    // the class calls the super implementation, or doesn't implement the selector and the
    // message just gets forwarded to the superclass.
    //
    // Therefore we should only swizzle on the furthest ancestor
    recipient = [self furthestAncestorOfRecipient:recipient
                             implementingSelector:sel];
    
    if ([[_RPTClassManipulator _classNameForSelector:sel class:recipient] isEqualToString:NSStringFromClass(recipient)])
    {
        // Same selector and recipient - already swizzled
        return;
    }
    
    Method m = class_getInstanceMethod(recipient, sel);
    IMP originalImplementation = NULL;
    
    if (m)
    {
        originalImplementation = method_setImplementation(m, newImp);
    }
    else
    {
        // add method, there's no original implementation
        class_addMethod(recipient, sel, newImp, types);
    }
    [self _addSelectorMapping:sel class:recipient implementation:originalImplementation];
}

+ (void)_removeSwizzleSelector:(SEL)sel onClass:(Class)recipient types:(const char *)types
{
    if (!sel || !recipient || !types)
    {
        return;
    }
    
    if (![[_RPTClassManipulator _classNameForSelector:sel class:recipient] isEqualToString:NSStringFromClass(recipient)])
    {
        // No swizzle has been added
        return;
    }
    
    Method m = class_getInstanceMethod(recipient, sel);
    IMP originalImplementation = [self implementationForOriginalSelector:sel class:recipient];
    IMP swizzleImplementation = NULL;
    
    // We can only safely reverse the swizzling if there was an original implementation
    if (m && originalImplementation)
    {
        swizzleImplementation = method_setImplementation(m, originalImplementation);
        imp_removeBlock(swizzleImplementation);
        [self _removeSelectorMapping:sel class:recipient];
    }
}

+ (_Nullable IMP)implementationForOriginalSelector:(SEL)selector class:(Class)clazz
{
    Class classObj = [self furthestAncestorOfRecipient:clazz
                                  implementingSelector:selector];
    NSString *key = [self _keyForSelector:selector class:classObj];
    SwizzleDetail *swizzleDetail = _swizzleMap[key];
    return [swizzleDetail.originalImplementation pointerValue];
}

+ (void)_addSelectorMapping:(SEL)selector class:(Class)classObj implementation:(__nullable IMP)implementation
{
    SwizzleDetail *swizzleDetail = [SwizzleDetail swizzleDetailWithClass:NSStringFromClass(classObj) implementation:implementation];
    if (swizzleDetail)
    {
        NSString *key = [self _keyForSelector:selector class:classObj];
        _swizzleMap[key] = swizzleDetail;
    }
}

+ (void)_removeSelectorMapping:(SEL)selector class:(Class)classObj
{
    if (!selector || !classObj) return;

    NSString *key = [self _keyForSelector:selector class:classObj];
    [_swizzleMap removeObjectForKey:key];
}

+ (NSString *)_classNameForSelector:(SEL)selector class:(Class)classObj
{
    NSString *key = [self _keyForSelector:selector class:classObj];
    SwizzleDetail *swizzleDetail = _swizzleMap[key];
    if (swizzleDetail)
    {
        return swizzleDetail.className;
    }
    return nil;
}

+ (NSString *)_keyForSelector:(SEL)selector class:(Class)classObj
{
    return (selector && classObj) ? [NSString stringWithFormat:@"%@-%@", NSStringFromSelector(selector), NSStringFromClass(classObj)] : nil;
}

@end
