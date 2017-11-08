#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

RPT_EXPORT const NSTimeInterval _RPT_MEASUREMENT_MAXTIME;

typedef NS_ENUM(NSUInteger, _RPTMeasurementKind)
{
    _RPTMetricMeasurementKind = 1,
    _RPTMethodMeasurementKind,
    _RPTURLMeasurementKind,
    _RPTDeviceMeasurementKind,
    _RPTCustomMeasurementKind,
};

RPT_EXPORT @interface _RPTMeasurement : NSObject
@property (atomic)                    _RPTMeasurementKind kind;
@property (atomic)                    uint_fast64_t       trackingIdentifier;
@property (atomic)                    NSTimeInterval      startTime;
@property (atomic)                    NSTimeInterval      endTime;
@property (nonatomic, nullable)       NSObject           *receiver;
@property (nonatomic, copy, nullable) NSString           *method;
@property (nonatomic, copy, nullable) NSString           *screen;

- (void)clear;
@end

NS_ASSUME_NONNULL_END
