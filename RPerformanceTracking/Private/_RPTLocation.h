#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

RPT_EXPORT @interface _RPTLocationFetcher : NSObject

/*
 * Fetch location from server
 */
+ (void)fetch;

@end

RPT_EXPORT @interface _RPTLocation : NSObject

/*
 * Location of the user.
 */
@property (nonatomic, readonly, copy) NSString *location;

/*
 * Country of the user
 */
@property (nonatomic, readonly, copy) NSString *country;

/*
 * Load location of user from disk if it was persisted.
 */
+ (instancetype)loadLocation;

/*
 * Save location based on data obtained from the Location API.
 */
+ (void)persistWithData:(NSData *)data;

- (instancetype)initWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
