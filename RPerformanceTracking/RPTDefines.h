#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/*
 * Exports a global, setting the proper visibility attributes so that it does not
 * get stripped at linktime.
 */
#ifdef __cplusplus
#   define RPT_EXPORT extern "C" __attribute__((visibility ("default")))
#else
#   define RPT_EXPORT extern __attribute__((visibility ("default")))
#endif

/*
 * Support for exposing public parts of the API with Swift3-specific names.
 * Note: We assume Xcode 9 won't support Swift 2 anymore.
 */
#if __has_attribute(swift_name) && ((__apple_build_version__ >= 9000000) || ((__apple_build_version__ >= 8000000) && (SWIFT_SDK_OVERLAY_DISPATCH_EPOCH >= 2)))
#  define RPT_SWIFT3_NAME(n) __attribute__((swift_name(#n)))
#else
#  define RPT_SWIFT3_NAME(n)
#endif

#if !__has_feature(objc_generics)
#error "Your compiler is not supported. Please use Xcode 8+"
#endif

