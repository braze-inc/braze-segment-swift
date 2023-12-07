import BrazeKit
import Foundation
import Segment
import os

#if canImport(BrazeUI)
  import BrazeUI
#endif

// MARK: - BrazeDestination

/// The Braze destination plugin for the Segment SDK.
///
/// The Braze destination can be used like any other Segment destination and will inherit the
/// settings from the Segment dashboard:
/// ```
/// analytics.add(plugin: BrazeDestination())
/// ```
///
/// To customize the Braze SDK further, you can use the `additionalConfiguration` closure:
/// ```
/// let brazeDestination = BrazeDestination(
///   additionalConfiguration: { configuration in
///     // Enable debug / verbose logs
///     configuration.logger.level = .debug
///
///     // Enable push support (disabling automatic push authorization prompt)
///     configuration.push.automation = true
///     configuration.push.automation.requestAuthorizationAtLaunch = false
///   }
/// )
/// analytics.add(plugin: BrazeDestination())
/// ```
///
/// An `additionalSetup` closure is also available to customize the Braze SDK further after it has
/// been initialized:
/// ```
/// let brazeDestination = BrazeDestination(
///   additionalSetup: { braze in
///     // Save the Braze instance on the AppDelegate for later use.
///     AppDelegate.braze = braze
///   }
/// )
/// analytics.add(plugin: BrazeDestination())
/// ```
///
/// See the Braze Swift SDK [documentation][1] for more information.
///
/// [1]: https://braze-inc.github.io/braze-swift-sdk
@available(iOS 14.0, *)
public class BrazeDestination: DestinationPlugin, VersionedPlugin {

  // MARK: - Properties

  // - DestinationPlugin

  public let timeline = Timeline()
  public let type = PluginType.destination
  public let key = "Appboy"
  public weak var analytics: Analytics? = nil {
    didSet {
      idfaPlugin.analytics = analytics
    }
  }

  private var idfaPlugin = BrazeIDFAPlugin()
  // - Braze

  /// The Braze instance.
  public internal(set) var braze: Braze? = nil


  #if canImport(BrazeUI)
    /// The Braze in-app message UI, available when `automaticInAppMessageRegistrationEnabled` is
    /// set to `true` on the Segment dashboard.
    public internal(set) var inAppMessageUI: BrazeInAppMessageUI? = nil
  #endif

  private let additionalConfiguration: ((Braze.Configuration) -> Void)?
  private let additionalSetup: ((Braze) -> Void)?

  // - Braze / Segment bridge

  private var logPurchaseWhenRevenuePresent: Bool = true

  // MARK: - Initialization

  /// Creates and returns a Braze destination plugin for the Segment SDK.
  ///
  /// See ``BrazeDestination`` for more information.
  ///
  /// - Parameters:
  ///   - additionalConfiguration: When provided, this closure is called with the Braze
  ///       configuration object before the SDK initialization. You can use this to set additional
  ///       Braze configuration options (e.g. session timeout, push notification automation, etc.).
  ///   - additionalSetup: When provided, this closure is called with the fully initialized Braze
  ///       instance. You can use this to customize further your usage of the Braze SDK (e.g.
  ///       register UI delegates, messaging subscriptions, etc.)
  public init(
    additionalConfiguration: ((Braze.Configuration) -> Void)? = nil,
    additionalSetup: ((Braze) -> Void)? = nil
  ) {
    self.additionalConfiguration = additionalConfiguration
    self.additionalSetup = additionalSetup
  }

  // MARK: - Plugin

  public func update(settings: Settings, type: UpdateType) {
    guard
      type == .initial,
      let brazeSettings: BrazeSettings = settings.integrationSettings(forPlugin: self),
      let configuration = makeBrazeConfiguration(from: brazeSettings)
    else {
      log(
        message:
          """
          Invalid settings, BrazeDestination will not be initialized:
          - settings: \(settings.prettyPrint())
          """
      )
      return
    }
    self.log(message: "Braze Destination is enabled")
    braze = makeBraze(from: brazeSettings, configuration: configuration)
    logPurchaseWhenRevenuePresent = brazeSettings.logPurchaseWhenRevenuePresent ?? true
  }

  // MARK: - EventPlugin

  public func identify(event: IdentifyEvent) -> IdentifyEvent? {

    guard let braze else { return event }

    if let userId = event.userId, !userId.isEmpty {
      braze.changeUser(userId: userId)
    }

    guard let traits = event.traits?.dictionaryValue else { return event }

    // Defined / known user attributes
    if let birthday = traits["birthday"] as? String {
      let dateformatter = DateFormatter()
      dateformatter.locale = Locale(identifier: "en_US_POSIX")
      dateformatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"  // RFC3339 format date
      let formattedBirthday = dateformatter.date(from: birthday)
      braze.user.set(dateOfBirth: formattedBirthday)
    }

    if let email = traits["email"] as? String {
      braze.user.set(email: email)
    }

    if let firstName = traits["firstName"] as? String {
      braze.user.set(firstName: firstName)
    }

    if let lastName = traits["lastName"] as? String {
      braze.user.set(lastName: lastName)
    }

    if let gender = (traits["gender"] as? String)?.lowercased() {
      if Keys.maleTokens.contains(gender) {
        braze.user.set(gender: .male)
      } else if Keys.femaleTokens.contains(gender) {
        braze.user.set(gender: .female)
      } else if Keys.notApplicableTokens.contains(gender) {
        braze.user.set(gender: .notApplicable)
      } else if gender.lowercased() == "other" {
        braze.user.set(gender: .other)
      } else if gender.lowercased() == "prefer not to say" {
        braze.user.set(gender: .preferNotToSay)
      } else {
        braze.user.set(gender: .unknown)
      }
    }

    if let phone = traits["phone"] as? String {
      braze.user.set(phoneNumber: phone)
    }

    if let address = traits["address"] as? [String: Any] {
      if let city = address["city"] as? String {
        braze.user.set(homeCity: city)
      }
      if let country = address["country"] as? String {
        braze.user.set(country: country)
      }
    }

    // Subscription groups
    if let subscriptions = traits[Keys.subscriptionGroup.rawValue] as? [[String: Any]] {
      for subscription in subscriptions {
        guard
          let groupID = subscription[Keys.subscriptionId.rawValue] as? String,
          let groupState = subscription[Keys.subscriptionGroupState.rawValue] as? String
            ?? subscription[Keys.subscriptionStateId.rawValue] as? String
        else { continue }
        switch groupState {
        case "subscribed":
          braze.user.addToSubscriptionGroup(id: groupID)
        case "unsubscribed":
          braze.user.removeFromSubscriptionGroup(id: groupID)
        default:
          log(message: "Unsupported subscription state '\(groupState)' for group '\(groupID)'")
        }
      }
    }

    // Custom user attributes
    for trait in traits where !Keys.reservedKeys.contains(trait.key) {
      let key = trait.key
      switch trait.value {
      case let value as String:
        braze.user.setCustomAttribute(key: key, value: value)
      case let value as Date:
        braze.user.setCustomAttribute(key: key, value: value)
      case let value as Bool:
        braze.user.setCustomAttribute(key: key, value: value)
      case let value as Int:
        braze.user.setCustomAttribute(key: key, value: value)
      case let value as Double:
        braze.user.setCustomAttribute(key: key, value: value)
      case let value as [String]:
        braze.user.setCustomAttribute(key: key, array: value)
      case let value as [String: Any?]:
        braze.user.setCustomAttribute(key: key, dictionary: formatDictionary(value))
      case let value as [[String: Any?]]:
        let formattedArray = value.map { formatDictionary($0) }
        braze.user.setCustomAttribute(key: key, array: formattedArray)
      case let value as [Any?]:
        braze.user.setCustomAttribute(key: key, array: castToStringArray(value))
      default:
        braze.user.setCustomAttribute(key: key, value: String(describing: trait.value))
      }
    }

    return event
  }

  public func track(event: TrackEvent) -> TrackEvent? {
    let properties = event.properties
    let revenue = extractRevenue(key: "revenue", from: properties?.dictionaryValue)
    let treatAsPurchase = revenue != nil && logPurchaseWhenRevenuePresent

    switch event.event {
    case Keys.installEventName.rawValue:
      setAttributionData(properties: properties)
    case Keys.purchaseEventName1.rawValue where treatAsPurchase,
      Keys.purchaseEventName2.rawValue where treatAsPurchase:
      logPurchase(name: event.event, properties: event.properties?.dictionaryValue ?? [:])
    default:
      logCustomEvent(name: event.event, properties: event.properties?.dictionaryValue)
    }

    return event
  }

  public func reset() {
    self.log(message: "Wiping data and resetting Braze.")
    braze?.wipeData()
    braze?.enabled = true
  }

  public func flush() {
    self.log(message: "Calling braze.requestImmediateDataFlush().")
    braze?.requestImmediateDataFlush()
  }

  // MARK: - VersionedPlugin

  public static func version() -> String { _version }

  // MARK: - Private Methods

  private func makeBrazeConfiguration(from settings: BrazeSettings) -> Braze.Configuration? {
    guard let endpoint = settings.customEndpoint else { return nil }
    let configuration = Braze.Configuration(apiKey: settings.apiKey, endpoint: endpoint)
    configuration.api.addSDKMetadata([.segment])
    configuration.api.sdkFlavor = .segment
    return configuration
  }

  private func makeBraze(
    from settings: BrazeSettings,
    configuration: Braze.Configuration
  ) -> Braze {
    additionalConfiguration?(configuration)

    let braze = Braze(configuration: configuration)



      if #available(iOS 14.0, *) {
          print("[] create logger")
          let logger = Logger(subsystem: "com.braze.segment",
                              category: "com.braze.segment")

          logger.info("Check if can if can import BrazeUI")

        #if canImport(BrazeUI)
          if settings.automaticInAppMessageRegistrationEnabled == true {
              logger.info("Can import braze ui - set in app message presenter")

              inAppMessageUI = BrazeInAppMessageUI()
              braze.inAppMessagePresenter = inAppMessageUI
          }
    #endif
      }


    additionalSetup?(braze)

    idfaPlugin.braze = braze
    add(plugin: idfaPlugin)

    return braze
  }

  private func setAttributionData(properties: JSON?) {
    let attributionData = Braze.User.AttributionData(
      network: properties?.value(forKeyPath: "campaign.source"),
      campaign: properties?.value(forKeyPath: "campaign.name"),
      adGroup: properties?.value(forKeyPath: "campaign.ad_group"),
      creative: properties?.value(forKeyPath: "campaign.as_creative")
    )
    braze?.user.set(attributionData: attributionData)
  }

  private func logPurchase(name: String, properties: [String: Any]) {
    let currency: String = properties["currency"] as? String ?? "USD"

    // - Multiple products in a single event.
    if let products = properties["products"] as? [[String: Any]] {
      for var product in products {
        // - Retrieve fields
        let productId = product["productId"] as? String ?? "Unknown"
        let price = extractRevenue(key: "price", from: product) ?? 0
        let quantity = product["quantity"] as? Int
        // - Cleanup
        product["productId"] = nil
        product["price"] = nil
        product["quantity"] = nil
        // - Merge with root properties
        let productProperties = properties.merging(product) { _, new in new }
        // - Log
        braze?.logPurchase(
          productId: productId,
          currency: currency,
          price: price,
          quantity: quantity ?? 0,
          properties: productProperties
        )
      }
      return
    }

    // - Regular purchase event.
    let price = extractRevenue(key: "revenue", from: properties) ?? 0
    braze?.logPurchase(
      productId: name,
      currency: currency,
      price: price,
      properties: properties
    )
  }

  private func logCustomEvent(name: String, properties: [String: Any]?) {
    var properties = properties
    properties?["revenue"] = nil
    properties?["currency"] = nil
    braze?.logCustomEvent(name: name, properties: properties)
  }

  private func extractRevenue(key: String, from properties: [String: Any]?) -> Double? {
    if let revenueDouble = properties?[key] as? Double {
      return revenueDouble
    }

    if let revenueString = properties?[key] as? String {
      let revenueDouble = Double(revenueString)
      return revenueDouble
    }

    return nil
  }

  private func log(message: String) {
    analytics?.log(message: "[BrazeSegment] \(message)")
  }
  
  /// Prepares the object dictionary to be sent upstream to Braze.
  private func formatDictionary(_ jsonObject: [String: Any?]) -> [String: Any?] {
    jsonObject.mapValues { object in
      switch object {
      case let stringArray as [String]:
        return stringArray
      case let jsonArray as [Any?]:
        return formatArray(jsonArray)
      case let dictionary as [String: Any?]:
        return formatDictionary(dictionary)
      default:
        return object
      }
    }
  }
  
  /// Formats the array to convert any non-string values to strings.
  private func formatArray(_ jsonArray: [Any?]) -> [Any] {
    jsonArray.compactMap { object in
      guard let object else {
        self.log(message: "Failed to format JSON array element: \(String(describing: object))")
        return nil
      }
      switch object {
      // Short-circuit arrays already containing strings to avoid re-converting them.
      case let stringArray as [String]:
        return stringArray
      case let dictionary as [String: Any?]:
        return formatDictionary(dictionary)
      case let nestedArray as [Any?]:
        return formatArray(nestedArray)
      default:
        return "\(object)"
      }
    }
  }
  
  /// Fallback to casting the entire array to strings if it doesn't match a Braze-accepted format.
  private func castToStringArray(_ jsonArray: [Any?]) -> [String] {
    jsonArray.compactMap { object in
      guard let object else {
        self.log(message: "Failed to stringify JSON array element: \(String(describing: object))")
        return nil
      }
      if let string = object as? String {
        return string
      } else {
        return "\(object)"
      }
    }
  }

  // MARK: - Keys

  private enum Keys: String {
    case installEventName = "Install Attributed"
    case purchaseEventName1 = "Order Completed"
    case purchaseEventName2 = "Completed Order"

    case subscriptionGroup = "braze_subscription_groups"
    case subscriptionId = "subscription_group_id"
    case subscriptionStateId = "subscription_state_id"
    case subscriptionGroupState = "subscription_group_state"

    static let maleTokens: Set<String> = ["m", "male"]
    static let femaleTokens: Set<String> = ["f", "female"]
    static let notApplicableTokens: Set<String> = ["na", "not applicable"]

    static let reservedKeys: Set<String> = [
      "birthday",
      "email",
      "firstName",
      "lastName",
      "gender",
      "phone",
      "address",
      "anonymousId",
      "userId",
      Keys.subscriptionGroup.rawValue,
    ]
  }

}

// MARK: - Settings

private struct BrazeSettings: Codable {
  let apiKey: String
  let customEndpoint: String?
  let automaticInAppMessageRegistrationEnabled: Bool?
  let logPurchaseWhenRevenuePresent: Bool?

  enum CodingKeys: String, CodingKey {
    case apiKey
    case customEndpoint
    case automaticInAppMessageRegistrationEnabled = "automatic_in_app_message_registration_enabled"
    case logPurchaseWhenRevenuePresent
  }
}
