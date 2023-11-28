## 2.2.0

#### Added
- Updates the Braze Swift SDK bindings to include releases from the 7.X.X SemVer denomination.
  - This allows compatibility with any version of the Braze SDK from `6.6.0` up to, but not including, `8.0.0`.
  - This is not a breaking change unless you choose to update to `7.0.0` and up. For further details, refer to the `7.0.0` [release notes](https://github.com/braze-inc/braze-swift-sdk/blob/main/CHANGELOG.md#700).

## 2.1.0

#### Added
- Adds the key `subscription_group_state` for setting the subscribed/unsubscribed status when using `braze_subscription_groups` in the Identify call.
  - Use this value instead of `subscription_state_id`.
- Adds support for nested custom attributes.
  - If the object sent through Segment's `Identify` call has values that are of type `[String: Any?]`, those values will be sent to Braze as a nested custom attribute.
  - If the object sent through Segment's `Identify` call contains an array, the values of that array will be converted to strings, and the array will be reported to Braze as an array of strings.

## 2.0.0

#### Added
- Renames this repository from `analytics-swift-braze` to `braze-segment-swift`.
  - This repository is now located at https://github.com/braze-inc/braze-segment-swift.
- Adds the `SegmentBrazeUI` module, which provides the `BrazeDestination` plugin with `BrazeUI` support.
  - Use the `SegmentBraze` module if you do not need any Braze-provided UI.
- Adds two optional parameters to the `BrazeDestination` initializer:
  - `additionalConfiguration`: When provided, this closure is called with the Braze
      configuration object before the SDK initialization. You can use this to set additional
      Braze configuration options (e.g. session timeout, push notification automation, etc.).
  - `additionalSetup`: When provided, this closure is called with the fully initialized Braze
      instance. You can use this to further customize your usage of the Braze SDK (e.g.
      register UI delegates, set up messaging subscriptions, etc.)
  - See the updated Sample App for an example of how to use these new parameters.
- Adds support for automatically forwarding the [advertisingIdentifier](https://developer.apple.com/documentation/adsupport/asidentifiermanager/1614151-advertisingidentifier) (_IDFA_) to Braze when making use of the [`IDFACollection`](https://github.com/segmentio/analytics-swift/blob/main/Examples/other_plugins/IDFACollection.swift) Segment plugin.
- Adds support to parse `braze_subscription_groups` in the Identity traits to subscribe and unsubscribe from Braze subscription groups.

## 1.0.0

Initial release.
