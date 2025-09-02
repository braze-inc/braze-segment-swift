import BrazeKit
import Segment

/// Internal plugin that forwards IDFA (Identifier for Advertisers) data from Segment to Braze.
///
/// This plugin automatically extracts IDFA information from Segment event context and forwards
/// it to the Braze SDK for advertising attribution and tracking purposes. It operates as an
/// enrichment plugin that processes all events passing through the Segment pipeline.
///
/// ## Functionality
///
/// The plugin monitors event context for:
/// - `device.adTrackingEnabled`: Whether ad tracking is enabled for the device
/// - `device.advertisingId`: The device's advertising identifier (IDFA)
///
/// When these values are present, they are automatically forwarded to Braze using the
/// appropriate SDK methods.
///
/// ## Usage
///
/// This plugin is automatically added to the `BrazeDestination` timeline when the destination
/// is initialized. It requires no manual configuration and operates transparently:
///
/// ```swift
/// // IDFA plugin is automatically added when using BrazeDestination
/// analytics.add(plugin: BrazeDestination())
/// 
/// // When using Segment's IDFACollection plugin, data is automatically forwarded
/// analytics.add(plugin: IDFACollection())
/// ```
///
/// ## Requirements
///
/// - Requires a valid Braze instance to be set before processing events
/// - Works in conjunction with Segment's IDFACollection plugin for optimal results
/// - Operates as a no-op when no IDFA data is available
///
/// ## Testing Considerations
///
/// This plugin's core functionality (IDFA data forwarding to Braze backend) is not
/// effectively unit-testable without exposing internal SDK state, which is not planned.
/// 
/// **For Future Contributors:**
/// - Simple logic changes can be unit tested (initialization, basic data extraction)
/// - Core IDFA forwarding requires integration or end-to-end testing infrastructure
/// - Any new complexity should be validated through appropriate testing strategies
/// - Consider extraction patterns if testable business logic emerges
///
/// The absence of unit tests for this plugin is intentional, reflecting the current
/// architectural constraints rather than a testing gap.
///
/// - Note: This is an internal plugin used by `BrazeDestination` and is not intended
///   for direct use by application developers.
class BrazeIDFAPlugin: Plugin {
  
  // MARK: - Properties
  
  /// The type of plugin this represents in the Segment pipeline.
  /// 
  /// Always returns `.enrichment` to indicate this plugin enriches events with
  /// additional data rather than being a final destination.
  var type: PluginType = .enrichment
  
  /// A weak reference to the Segment Analytics instance.
  /// 
  /// This reference is set by the parent `BrazeDestination` and is used for
  /// accessing Segment SDK functionality when needed.
  weak var analytics: Analytics?
  
  /// A weak reference to the Braze SDK instance.
  /// 
  /// This reference is set by the parent `BrazeDestination` after Braze SDK
  /// initialization. The plugin will not process events until this is set.
  weak var braze: Braze?

  // MARK: - Plugin Execution
  
  /// Processes an event to extract and forward IDFA data to Braze.
  ///
  /// This method examines the event context for IDFA-related information and forwards
  /// it to the Braze SDK when available. It operates transparently on all event types
  /// without modifying the event data.
  ///
  /// ## Processing Logic
  ///
  /// 1. Checks if Braze SDK is available (returns early if not)
  /// 2. Extracts `device.adTrackingEnabled` and forwards to Braze
  /// 3. Extracts `device.advertisingId` and forwards to Braze
  /// 4. Returns the original event unchanged
  ///
  /// ## Event Context Structure
  ///
  /// The plugin looks for IDFA data in the following event context structure:
  /// ```swift
  /// {
  ///   "context": {
  ///     "device": {
  ///       "adTrackingEnabled": true,
  ///       "advertisingId": "12345678-1234-1234-1234-123456789012"
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter event: The event to process for IDFA data extraction.
  /// - Returns: The original event unchanged, allowing other plugins to process it.
  ///
  /// - Note: This method is called for every event in the Segment pipeline and is
  ///   designed to be lightweight and non-blocking.
  func execute<T>(event: T?) -> T? where T : RawEvent {
    guard let braze else { return event }

    if let context = event?.context?.dictionaryValue {
      if let adTrackingEnabled = context[keyPath: "device.adTrackingEnabled"] as? Bool {
        braze.set(adTrackingEnabled: adTrackingEnabled)
      }

      if let idfa = context[keyPath: "device.advertisingId"] as? String {
        braze.set(identifierForAdvertiser: idfa)
      }
    }

    return event
  }
}
