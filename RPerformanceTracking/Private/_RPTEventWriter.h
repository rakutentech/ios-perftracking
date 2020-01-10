#import <RPerformanceTracking/RPTDefines.h>

@class _RPTConfiguration, _RPTMetric, _RPTMeasurement;

NS_ASSUME_NONNULL_BEGIN

@protocol RPTEventWriterHandleNetworkResponse <NSObject>

- (void)handleURLResponse:(nullable NSURLResponse *)response error:(nullable NSError *)error;

@end

@interface _RPTEventWriter : NSObject
@property (nonatomic, weak) id delegate;

- (instancetype)initWithConfiguration:(_RPTConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (void)begin;
- (void)writeWithMetric:(_RPTMetric *)metric;
- (void)writeWithMeasurement:(_RPTMeasurement *)measurement metricIdentifier:(nullable NSString *)metricIdentifier;
- (void)end;
- (BOOL)writingInProgress;

@end

NS_ASSUME_NONNULL_END
