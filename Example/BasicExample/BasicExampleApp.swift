import Segment
import SegmentBraze
import SwiftUI

let segmentWriteKey = "6986CcMHxN4rXpYe3ieKBTtXQHryZVRi"

@main
struct BasicExampleApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

extension Analytics {
  static var main: Analytics = {
    let analytics = Analytics(
      configuration: Configuration(writeKey: segmentWriteKey)
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    )
    analytics.add(plugin: Analytics.makeBrazeDestination())
    return analytics
  }()

  static func makeBrazeDestination() -> BrazeDestination {
    BrazeDestination(
      additionalConfiguration: { configuration in
        // Configure the Braze SDK here, e.g.:
        // - Log general SDK information and errors
        configuration.logger.level = .info

        // - Enable automatic push notifications support
        configuration.push.automation = true
        configuration.push.automation.requestAuthorizationAtLaunch = false

        // - Enable universal link forwarding
        configuration.forwardUniversalLinks = true
        
        // - Set the trigger minimum time interval
        configuration.triggerMinimumTimeInterval = 35
      },
      additionalSetup: { braze in
        // Post initialization setup here (e.g. setting up delegates, subscriptions, keep a
        // reference to the initialized Braze instance, etc.)
      }
    )
  }
}
