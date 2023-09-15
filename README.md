# Braze-Segment-Swift

Add this plugin to your applications to support both the [Segment `Analytics-Swift` SDK](https://github.com/segmentio/analytics-swift) and the [Braze Swift SDK](https://github.com/braze-inc/braze-swift-sdk/).

## Adding the dependency

### via Xcode
In the Xcode `File` menu, click `Add Packages`.  You'll see a dialog where you can search for Swift packages.  In the search field, enter the URL to this repo.

```
https://github.com/braze-inc/braze-segment-swift
```

You'll then have the option to pin to a version, or specific branch, as well as select which project in your workspace to add it to. Once you've made your selections, click the `Add Package` button.

### via Package.swift

Open your `Package.swift` file and add the following do your the `dependencies` section:

```swift
.package(
  url: "https://github.com/braze-inc/braze-segment-swift",
  from: "2.0.0"
),
```

Update your target dependencies to include either `SegmentBraze` or `SegmentBrazeUI`:

```swift
.target(
  name: "...",
  dependencies: [
    .product(name: "Segment", package: "analytics-swift"),
    .product(name: "SegmentBraze", package: "braze-segment-swift"),
  ]
),
```

> Note: `SegmentBraze` does not provide any UI components and does not depend on `BrazeUI`. If you need UI components, use `SegmentBrazeUI` in place of `SegmentBraze` – but do not import both of them.

## Using the Plugin in your App

Open the file where you setup and configure the Analytics-Swift library. Add this plugin to the list of imports.

```swift
import Segment
import SegmentBraze // <-- Add this line, or replace with `import SegmentBrazeUI` if you need UI components
```

Just under your Analytics-Swift library setup, call `analytics.add(plugin: ...)` to add an instance of the plugin to the Analytics timeline.

```swift
let analytics = Analytics(configuration: Configuration(writeKey: "<YOUR WRITE KEY>")
                    .flushAt(3)
                    .trackApplicationLifecycleEvents(true))
analytics.add(plugin: BrazeDestination())
```

Your events will now be given Braze session data and start flowing to Braze.

### Additional Configuration

The `BrazeDestination` initializer accepts two optional parameters allowing you more control over the SDK's behavior. For a full list of available configurations, refer to [`Braze.Configuration`](https://braze-inc.github.io/braze-swift-sdk/documentation/brazekit/braze/configuration-swift.class).

```swift
BrazeDestination(
  additionalConfiguration: { configuration in
    // Configure the Braze SDK here, e.g.:
    // - Debug / verbose logs
    configuration.logger.level = .debug

    // - Enable automatic push notifications support
    configuration.push.automation = true
    configuration.push.automation.requestAuthorizationAtLaunch = false

    // - Enable universal link forwarding
    configuration.forwardUniversalLinks = true
  },
  additionalSetup: { braze in
    // Post initialization setup here (e.g. setting up delegates, subscriptions, keep a
    // reference to the initialized Braze instance, etc.)
  }
)
```

### Push Notifications Support

To enable push notifications support, refer to the [_Push Notifications_](https://www.braze.com/docs/developer_guide/platform_integration_guides/swift/push_notifications/) documentation. To keep the integration minimal, the Braze SDK provides push automation features (see sample code above and the [`automation`](https://braze-inc.github.io/braze-swift-sdk/documentation/brazekit/braze/configuration-swift.class/push-swift.class/automation-swift.property) documentation).

### IDFA Collection

When making use of the [`IDFACollection`](https://github.com/segmentio/analytics-swift/blob/main/Examples/other_plugins/IDFACollection.swift) Segment plugin, the `BrazeDestination` will automatically forward the collected IDFA to Braze.

## Questions?

If you have questions, please contact [support@braze.com](mailto:support@braze.com) or open a [GitHub Issue](https://github.com/braze-inc/braze-segment-swift/issues).
