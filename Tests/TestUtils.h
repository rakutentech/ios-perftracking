#ifndef TestUtils_h
#define TestUtils_h

@class _RPTTracker, _RPTMetric, _RPTMeasurement, _RPTRingBuffer, _RPTConfiguration;

NSData* mkConfigPayload_(NSDictionary* params);

_RPTMeasurement* mkMeasurementStub(NSDictionary* params);
_RPTRingBuffer* mkRingBufferStub(NSDictionary* params);
_RPTMetric* mkMetricStub(NSDictionary* params);
_RPTConfiguration* mkConfigurationStub(NSDictionary* params);

#endif

