## 5.0.1

#### Fixed
- Fixes the internal `logPurchase` method call to check for product IDs using the key `"product_id"` instead of `"productId"`.
  - This change is backwards compatible, but in the event that both keys are provided, `"product_id"` will take precedence over `"productId"`.
  - This aligns the Braze Segment plugin with the [V2 Ecommerce Events Spec](https://segment.com/docs/connections/spec/ecommerce/v2/).

## 5.0.0

#### Breaking
- Updates the Braze Swift SDK bindings to require releases from the `11.1.1+` SemVer denomination.
  - This allows compatibility with any version of the Braze SDK from `11.1.1` up to, but not including, `12.0.0`.
  - Refer to the changelog entry for [`11.1.1`](https://github.com/braze-inc/braze-swift-sdk/blob/main/CHANGELOG.md#1111) for more information on potential breaking changes.

## 4.0.0

#### Breaking
- Updates the Braze Swift SDK bindings to require releases from the `10.2.0+` SemVer denomination.
  - This allows compatibility with any version of the Braze SDK from `10.2.0` up to, but not including, `11.0.0`.
  - Refer to the changelog entry for [`10.0.0`](https://github.com/braze-inc/braze-swift-sdk/blob/main/CHANGELOG.md#1000) for more information on potential breaking changes.

## 3.0.0

#### Breaking
- Updates the Braze Swift SDK bindings to require releases from the `9.2.0+` SemVer denomination.
  - This allows compatibility with any version of the Braze SDK from `9.2.0` up to, but not including, `10.0.0`.
  - Refer to the changelog entries for [`7.0.0`](https://github.com/braze-inc/braze-swift-sdk/blob/main/CHANGELOG.md#700), [`8.0.0`](https://github.com/braze-inc/braze-swift-sdk/blob/main/CHANGELOG.md#800), and [`9.0.0`](https://github.com/braze-inc/braze-swift-sdk/blob/main/CHANGELOG.md#900) for more information on potential breaking changes.
- Push notification support now requires a call to the static method `BrazeDestination.prepareForDelayedInitialization()` as early as possible in the app lifecycle, in your application's `AppDelegate.application(_:didFinishLaunchingWithOptions:)` method.

#### Fixed
- Restore push notification support when the BrazeDestination plugin is integrated with Analytics-Swift `1.5.0+`.
  - See the _Breaking_ entry of the changelog for more information.

## 2.4.0

#### Added
- Updates the Braze Swift SDK bindings to include releases from the `9.X.X` SemVer denomination.
  - This allows compatibility with any version of the Braze SDK from `6.6.0` up to, but not including, `10.0.0`.

## 2.3.0

#### Added
- Updates the Braze Swift SDK bindings to include releases from the `8.X.X` SemVer denomination.
  - This allows compatibility with any version of the Braze SDK from `6.6.0` up to, but not including, `9.0.0`.

#### Fixed
- Fixes an issue introduced in `2.0.0` where the `execute` method was not being triggered in Segment middleware plugins.

## 2.2.0

#### Added
- Updates the Braze Swift SDK bindings to include releases from the `7.X.X` SemVer denomination.
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
