[![Build Status](https://travis-ci.org/rakutentech/ios-perftracking.svg?branch=master)](https://travis-ci.org/rakutentech/ios-perftracking)
[![codecov](https://codecov.io/gh/rakutentech/ios-perftracking/branch/master/graph/badge.svg)](https://codecov.io/gh/rakutentech/ios-perftracking)


# Performance Tracking

The **Performance Tracking** module is a tool that lets you measure the performance of your iOS mobile application. It does this by adding measurement calls to app lifecycle, network requests and some standard UIKit class methods.

## How it works

* Automatically initializes upon process launch:
  * Loads the configuration obtained from the configuration API on the previous run.
  * Determine if tracking should be enabled (using the ratio found in the configuration) and, if so, enables tracking, which:
    * Instruments iOS classes.
    * Initializes the ring buffer, the internal tracker, the connection to the backend and starts the sender loop on a background queue.
    * Starts the LAUNCH metric as soon as possible.
  * Updates the configuration for next launch, by making a request to the configuration API and saving the result.
  * The "sender" background queue periodically polls the ring buffer and sends measurements to the "event writer" which builds the JSON and sends the requests to the backend.

## Getting started

This module supports iOS 10.0 and above. It has been tested on iOS 10.0 and above.

### Installing as CocoaPods pod

To use the module your `Podfile` should contain:

    source 'https://github.com/CocoaPods/Specs.git'

    pod 'RPerformanceTracking'

Run `pod install` to install the module and its dependencies.

### Configuring

Currently we do not host any publicly accessible Performance Tracking backend APIs.

You must specify the following values in your application's info.plist in order to use the module:

| Key | Value |
|------|------|
| `RPTSubscriptionKey` | Only internal Rakuten developers can setup a key. If not a Rakuten developer set a non-empty string |
| `RPTConfigAPIEndpoint` | Endpoint to fetch the module configuration - see `_RPTConfiguration` class for response format |
| `RPTLocationAPIEndpoint` | Endpoint to fetch the current location - see `_RPTLocation` class for response format |
| `RPTRelayAppID` | Relay portal application ID. Only internal Rakuten developers can setup app ID. If not a Rakuten developer set a non-empty string |

Now your application is ready to automatically track the `Launch` metric, network requests, view lifecycle methods, and more.

On first run of your app after integrating Performance Tracking the module will only fetch and store its configuration data; it **will not** send metric data. On subsequent runs the module will track and send metrics and measurements if the previously received configuration is valid and the activation check succeeds.

### Verify data is collected and sent

 When you run your app in debug mode Xcode should display Performance Tracking debug logs prefixed with `[Performance Tracking]`. These logs show the measurements sent by the module to the backend for processing.

There may be a log that contains '`Tracking disabled`' which will show the reason for tracking not running, either because the Configuration API response data was invalid (in this case double-check the configuration keys you added to your info.plist) or because the result of that session's activation check was to disable tracking.

To help verify that tracking works in your app you can add a boolean flag `RPTForceTrackingEnabled` to your app's `info.plist` set to YES/true. This bypasses the activation check. After adding the flag run the app in debug mode and tracking should be enabled (as long as the Configuration API response was valid).

## Contributing

See the [contributing guide](CONTRIBUTING.md) for details of how to participate in development of the module.

## Changelog

See the [changelog](CHANGELOG.md) for the new features, changes and bug fixes of the module versions.
