## Changelog

### 1.1.0 (2018-02-08)
- REM-25644 By default use swizzling to track UIWebViews instead of a custom NSURLProtocol.
- REM-25242 Fix a bug with redirect handling by informing the custom protocol's client of redirect requests.
- REM-25138 Debug builds now always send performance data if config API response is valid and force tracking plist flag `RPTForceTrackingEnabled` is set true.
- REM-24817 Rewrite tracking to use IMP blocks for swizzling so that selectors are unchanged, thereby improving compatibility with 3rd party SDKs such as New Relic.
- REM-25817 Fix crash that occurs when info.plist keys are missing by failing safely in release builds.

### 1.0.0 (2017-12-01)
- REM-24598 Applications now have to configure their AppID in the Info.plist.
- REM-23677 Add application memory used, device memory used/free and battery level to measurement payload.
- REM-23675 Send a measurement to the backend when a watcher thread detects the main thread has been running for more than a certain threshold (currently 400ms).
- Fix a crash where we could pass a nil string argument to `containsString` method.

### 0.2.0 (2017-10-30)
- REM-23397 Add Metric.prolong to public API.
- REM-23407/REM-23408 Track URL requests in web views.
- REM-22695/REM-23145/REM-23450 Send more detailed information to backend. Measurement payload now includes start timestamp, OS version, and current screen in addition to existing fields.

### 0.1.1 (2017-08-03)
- REM-20918 Change the location information sent to the measurements backend from country only to region and country.

### 0.1.0 (2017-06-26)
- Initial MVP release
