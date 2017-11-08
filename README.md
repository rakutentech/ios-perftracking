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

### Installing as CocoaPods pod

At this time the module is not published as a public CocoaPods pod so you will need to clone the repository locally.

To use the module your `Podfile` should contain:

    source 'https://github.com/CocoaPods/Specs.git'

    pod 'RPerformanceTracking', :path => '/path-to-performance-tracking-podspec'

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

Build and run your app in the debug configuration and in the Xcode console you will see debug logs prefixed with `[Performance Tracking]`. These show the data sent by the module for processing by the backend.

There may be a log that contains '`Tracking disabled`' which will show the reason for tracking not running, either because the Configuration API response data was invalid (in this case double-check your API subscription key `RPTSubscriptionKey` in your info.plist) or because the result of the session's activation check is to disable tracking.

## Contributing

See the [contributing guide](CONTRIBUTING.md) for details of how to partipate in development of the module.
