## Changelog

### 1.3.1 (2019-05-13)
- APTT-759 Fix bug affecting 32-bit devices that resulted in tracking always being enabled regardless of the enable percentage value set in the portal
- APTT-741 Fix bug where metrics are not always sent due to the measurement buffer being full

### 1.3.0 (2018-12-18)

- Known issue: Due to an Apple issue it is not possible to track the response status code in UIWebViews in iOS 12. WKWebView is unaffected.
- APTT-662/APTT-675 Add ability to send tracking data to RAT and/or Azure depending on the `Data Storage` setting in the Rakuten App Studio Portal. Currently the only tracking data sent to RAT is network events.

### 1.2.0 (2018-06-13)

- REM-25613 Send network request and webview HTTP status code to backend.
- APTT-324 Send OS Version and Device Model to Config API. This enables the portal to offer better filtering.
- APTT-430 Collect measurements outside a metric depending on a flag in the Config API response. This will reduce unnecessary mobile data usage.
- REM-25625 Default to using swizzling to track UIWebViews.
- APTT-260 Do not swizzle webview delegates when tracking is disabled.
- REM-25979 Use GitHub hosted shared build config.
- REM-25743 Fix device measurement invalid timestamp bug.
- REM-25661 Fix bug where empty measurement url could occur.

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
