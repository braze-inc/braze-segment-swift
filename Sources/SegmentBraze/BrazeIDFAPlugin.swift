import BrazeKit
import Segment

class BrazeIDFAPlugin: Plugin {
  var type: PluginType = .enrichment
  weak var analytics: Analytics?
  weak var braze: Braze?

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
