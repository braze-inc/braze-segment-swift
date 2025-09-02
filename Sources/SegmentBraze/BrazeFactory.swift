import BrazeKit
import Foundation
import Segment

#if canImport(BrazeUI)
  import BrazeUI
#endif

// MARK: - Factory Protocol for Testing

/// Internal protocol for creating Braze instances - enables factory mocking
protocol BrazeFactoryProtocol {
  func createBraze(configuration: Braze.Configuration) -> Braze
  func prepareForDelayedInitialization()

  #if canImport(BrazeUI)
    @MainActor
    func createInAppMessageUI() -> BrazeInAppMessageUI
  #endif
}

// MARK: - Factory Implementation

/// Internal factory for creating Braze instances
class BrazeFactory: BrazeFactoryProtocol {

  func createBraze(configuration: Braze.Configuration) -> Braze {
    return Braze(configuration: configuration)
  }

  func prepareForDelayedInitialization() {
    Braze.prepareForDelayedInitialization()
  }

  #if canImport(BrazeUI)
    @MainActor
    func createInAppMessageUI() -> BrazeInAppMessageUI {
      return BrazeInAppMessageUI()
    }
  #endif
} 