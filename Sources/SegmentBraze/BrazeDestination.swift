import BrazeKit
import Foundation
import Segment

#if canImport(BrazeUI)
  import BrazeUI
#endif

// MARK: - BrazeDestination

/// The Braze destination plugin for the Segment SDK.
///
/// The Braze destination can be used like any other Segment destination and will inherit the
/// settings from the Segment dashboard:
/// ```swift
/// analytics.add(plugin: BrazeDestination())
/// ```
///
/// To customize the Braze SDK further, you can use the `additionalConfiguration` closure:
/// ```swift
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
/// ```swift
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
public class BrazeDestination: DestinationPlugin, VersionedPlugin {
  // MARK: - Properties

  // - DestinationPlugin

  /// The Segment timeline manages the execution flow of plugins within this destination.
  ///
  /// This timeline coordinates how events are processed and allows for sub-plugins
  /// to be added and managed within the destination plugin architecture.
  public let timeline: Timeline

  /// The type of plugin this destination represents.
  ///
  /// Always returns `.destination` to indicate this is a destination plugin that
  /// sends events to an external service (Braze).
  public let type: PluginType

  /// The unique identifier for this destination plugin.
  ///
  /// This key is used by the Segment SDK to identify and manage this destination.
  /// The value "Appboy" is used for historical compatibility with Braze's former name.
  public let key: String

  /// A weak reference to the Segment Analytics instance that owns this plugin.
  ///
  /// This reference is automatically set by the Segment SDK when the plugin is added
  /// to an Analytics instance. It's used for logging and accessing SDK functionality.
  public weak var analytics: Analytics?

  // - Braze

  /// The initialized Braze SDK instance.
  ///
  /// This property is `nil` until the destination is properly configured with valid
  /// Braze settings from the Segment dashboard. Once initialized, this instance
  /// is used to forward all events to the Braze SDK.
  public internal(set) var braze: Braze?

  private let brazeFactory: BrazeFactoryProtocol

  #if canImport(BrazeUI)
    /// The Braze in-app message UI component.
    ///
    /// This property is automatically initialized when `automaticInAppMessageRegistrationEnabled`
    /// is set to `true` in the Segment dashboard configuration. It provides the default
    /// UI for displaying Braze in-app messages.
    @MainActor
    public internal(set) var inAppMessageUI: BrazeInAppMessageUI? = nil
  #endif

  /// Configuration closure called before Braze SDK initialization.
  ///
  /// This closure allows customization of the Braze configuration object before
  /// the SDK is initialized, enabling advanced configuration options.
  private let additionalConfiguration: ((Braze.Configuration) -> Void)?

  /// Setup closure called after Braze SDK initialization.
  ///
  /// This closure is executed after the Braze SDK has been fully initialized,
  /// allowing for post-initialization setup like delegate registration.
  private let additionalSetup: (@MainActor (Braze) -> Void)?

  /// Internal plugin for handling IDFA (Identifier for Advertisers) data.
  ///
  /// This plugin automatically forwards IDFA information to Braze when the
  /// Segment IDFACollection plugin is used. It's a no-op if no IDFA is provided.
  private var idfaPlugin: Plugin

  // - Braze / Segment bridge

  /// Controls whether revenue events should be logged as purchases in Braze.
  ///
  /// When `true`, track events containing revenue will be sent to Braze as
  /// purchase events. This setting is configured via the Segment dashboard.
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
  public convenience init(
    additionalConfiguration: ((Braze.Configuration) -> Void)? = nil,
    additionalSetup: (@MainActor (Braze) -> Void)? = nil
  ) {
    self.init(
      timeline: Timeline(),
      type: .destination,
      key: "Appboy",
      additionalConfiguration: additionalConfiguration,
      additionalSetup: additionalSetup
    )
  }

  init(
    timeline: Timeline = Timeline(),
    type: PluginType = .destination,
    key: String = "Appboy",
    analytics: Analytics? = nil,
    braze: Braze? = nil,
    additionalConfiguration: ((Braze.Configuration) -> Void)? = nil,
    additionalSetup: (@MainActor (Braze) -> Void)? = nil,
    idfaPlugin: Plugin = BrazeIDFAPlugin(),
    logPurchaseWhenRevenuePresent: Bool = true,
    brazeFactory: BrazeFactoryProtocol = BrazeFactory()
  ) {
    // DestinationPlugin properties
    self.timeline = timeline
    self.type = type
    self.key = key
    self.analytics = analytics

    // Braze properties
    self.braze = braze
    self.additionalConfiguration = additionalConfiguration
    self.additionalSetup = additionalSetup
    self.idfaPlugin = idfaPlugin

    // Braze / Segment bridge properties
    self.logPurchaseWhenRevenuePresent = logPurchaseWhenRevenuePresent

    // Factory for dependency injection
    self.brazeFactory = brazeFactory
  }

  // MARK: - Plugin

  /// Updates the plugin with new settings from the Segment dashboard.
  ///
  /// This method is called by the Segment SDK when the plugin is first added to an
  /// Analytics instance or when settings are updated. It initializes the Braze SDK
  /// with the configuration received from the Segment dashboard.
  ///
  /// ## Behavior
  ///
  /// - Only processes `.initial` update types to avoid unnecessary reinitialization
  /// - Validates that valid Braze settings are present before initialization
  /// - Logs detailed error messages if settings are invalid
  /// - Configures the Braze SDK with Segment-specific metadata
  ///
  /// - Parameters:
  ///   - settings: The settings object containing integration configurations from
  ///     the Segment dashboard, including Braze-specific settings like API key and endpoint.
  ///   - type: The type of update being performed. Only `.initial` updates are processed.
  ///
  /// - Note: If invalid settings are provided, the Braze SDK will not be initialized
  ///   and the plugin will remain in a non-functional state until valid settings are received.
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
    log(message: "Braze Destination is enabled")
    braze = makeBraze(from: brazeSettings, configuration: configuration)
    logPurchaseWhenRevenuePresent = brazeSettings.logPurchaseWhenRevenuePresent ?? true
  }

  // MARK: - EventPlugin

  /// Processes an identify event and forwards user data to Braze.
  ///
  /// This method handles user identification and attribute setting in Braze. It processes
  /// the user ID and traits from the Segment identify event and maps them to appropriate
  /// Braze user attributes and properties.
  ///
  /// ## Supported Traits
  ///
  /// ### Standard Traits
  /// - `userId`: Changes the current user in Braze
  /// - `email`: Sets the user's email address
  /// - `firstName`: Sets the user's first name
  /// - `lastName`: Sets the user's last name
  /// - `birthday`: Sets the user's date of birth (ISO 8601 format)
  /// - `gender`: Sets the user's gender (supports various formats)
  /// - `phone`: Sets the user's phone number
  /// - `address`: Sets city and country from address object
  ///
  /// ### Special Traits
  /// - `braze_subscription_groups`: Array of subscription group configurations
  ///
  /// ### Custom Attributes
  /// All other traits are set as custom attributes in Braze with automatic type conversion.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// analytics.identify(userId: "user123", traits: [
  ///   "email": "user@example.com",
  ///   "firstName": "John",
  ///   "customAttribute": "value"
  /// ])
  /// ```
  ///
  /// - Parameter event: The identify event containing user ID and traits to process.
  /// - Returns: The original event unchanged, allowing other plugins to process it.
  ///
  /// - Note: This method requires the Braze SDK to be initialized. If the SDK is not
  ///   initialized, the event will be returned without processing.
  public func identify(event: IdentifyEvent) -> IdentifyEvent? {
    guard let braze else { return event }

    if let userId = event.userId, !userId.isEmpty {
      braze.changeUser(userId: userId)
    }

    guard let traits = event.traits?.dictionaryValue else { return event }
    processUserTraits(traits)

    return event
  }

  /// Processes a track event and forwards it to Braze as either a custom event or purchase.
  ///
  /// This method intelligently routes track events to the appropriate Braze method based
  /// on the event name and properties. It can handle regular custom events, attribution
  /// events, and purchase events with automatic revenue detection.
  ///
  /// - Parameter event: The track event containing event name and properties to process.
  /// - Returns: The original event unchanged, allowing other plugins to process it.
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

  /// Resets the Braze SDK to its initial state.
  ///
  /// This method clears all user data and state from the Braze SDK, effectively
  /// logging out the current user and preparing for a fresh user session. It's
  /// typically called when users log out or when switching between user accounts.
  ///
  /// - Note: After calling reset, the SDK will be ready to track a new user.
  ///   Any subsequent identify or track calls will be associated with the new user.
  public func reset() {
    log(message: "Wiping data and resetting Braze.")
    braze?.wipeData()
    braze?.enabled = true
  }

  /// Forces an immediate flush of all queued events to Braze servers.
  ///
  /// This method bypasses the normal batching and timing mechanisms to send all
  /// pending events immediately. It's useful for ensuring critical events are
  /// sent before app termination or in situations where immediate data delivery
  /// is required.
  ///
  /// - Note: Use sparingly as frequent immediate flushes can impact app performance
  ///   and increase battery usage.
  public func flush() {
    log(message: "Calling braze.requestImmediateDataFlush().")
    braze?.requestImmediateDataFlush()
  }

  // MARK: - VersionedPlugin

  /// Returns the current version of the Braze destination plugin.
  ///
  /// This method provides the version information for the plugin, which is used
  /// by the Segment SDK for debugging, logging, and compatibility checks. The
  /// version follows semantic versioning principles.
  ///
  /// - Returns: A string representing the current version of the plugin (e.g., "1.0.0").
  ///
  /// - Note: This is a static method that can be called without creating an instance
  ///   of the destination plugin.
  public static func version() -> String { _version }

  // MARK: - Delayed Initialization

  /// Prepares the Braze SDK to support delayed initialization for proper push notification handling.
  ///
  /// This method configures the Braze SDK to handle push notifications that may be received
  /// before the SDK is fully initialized through the Segment plugin system. It's essential
  /// for ensuring that push notifications are properly processed in apps that use
  /// asynchronous plugin initialization.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// func application(
  ///   _ application: UIApplication,
  ///   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  /// ) -> Bool {
  ///   // Call this before setting up Segment Analytics
  ///   BrazeDestination.prepareForDelayedInitialization()
  ///
  ///   // Initialize Segment Analytics
  ///   analytics.add(plugin: BrazeDestination())
  ///
  ///   return true
  /// }
  /// ```
  ///
  /// - Important: This method must be called as soon as possible in the application lifecycle,
  ///   ideally in or before `application(_:didFinishLaunchingWithOptions:)`.
  ///
  /// - Note: This is a static method that configures global Braze SDK behavior and should
  ///   only be called once per app launch.
  public static func prepareForDelayedInitialization() {
    Braze.prepareForDelayedInitialization()
  }

  // MARK: - Private Methods

  /// Creates a Braze configuration object from Segment settings.
  ///
  /// This method extracts the necessary configuration parameters from the Segment
  /// settings object and creates a properly configured Braze configuration instance.
  ///
  /// - Parameter settings: The Braze settings extracted from Segment dashboard configuration.
  /// - Returns: A configured `Braze.Configuration` object, or `nil` if required settings are missing.
  private func makeBrazeConfiguration(from settings: BrazeSettings) -> Braze.Configuration? {
    guard let endpoint = settings.customEndpoint else { return nil }
    let configuration = Braze.Configuration(apiKey: settings.apiKey, endpoint: endpoint)
    configuration.api.addSDKMetadata([.segment])
    configuration.api.sdkFlavor = .segment
    return configuration
  }

  /// Initializes the Braze SDK with the provided settings and configuration.
  ///
  /// This method handles the complete initialization process including running
  /// configuration and setup closures, initializing UI components, and setting up sub-plugins.
  ///
  /// - Parameters:
  ///   - settings: The Braze settings containing dashboard configuration.
  ///   - configuration: The Braze configuration object to use for initialization.
  /// - Returns: A fully initialized and configured Braze instance.
  private func makeBraze(
    from settings: BrazeSettings,
    configuration: Braze.Configuration
  ) -> Braze {
    // Use the internal factory pattern for better testability
    let brazeInstance = createBrazeInstance(from: settings, configuration: configuration)

    // Set up IDFA plugin with the Braze instance
    (idfaPlugin as? BrazeIDFAPlugin)?.braze = brazeInstance
    idfaPlugin.analytics = analytics
    add(plugin: idfaPlugin)

    return brazeInstance
  }

  /// Sets attribution data in Braze from campaign properties.
  ///
  /// This method processes attribution data from Install Attributed events and
  /// forwards it to Braze for attribution tracking and campaign analysis.
  ///
  /// - Parameters:
  ///   - properties: The event properties containing campaign attribution data.
  private func setAttributionData(properties: JSON?) {
    let attributionData = Braze.User.AttributionData(
      network: properties?.value(forKeyPath: "campaign.source"),
      campaign: properties?.value(forKeyPath: "campaign.name"),
      adGroup: properties?.value(forKeyPath: "campaign.ad_group"),
      creative: properties?.value(forKeyPath: "campaign.as_creative")
    )
    braze?.user.set(attributionData: attributionData)
  }

  /// Logs a purchase event in Braze with proper product handling.
  ///
  /// This method handles both single-product and multi-product purchases, extracting
  /// relevant product information and forwarding it to Braze's purchase tracking.
  ///
  /// ## Supported Formats
  ///
  /// ### Single Product
  /// Uses the event name as product ID and extracts revenue from properties.
  ///
  /// ### Multiple Products
  /// Processes a `products` array, logging each product as a separate purchase.
  ///
  /// - Parameters:
  ///   - name: The event name (used as product ID for single products).
  ///   - properties: The event properties containing purchase data.
  private func logPurchase(name: String, properties: [String: Any]) {
    let currency: String = properties["currency"] as? String ?? "USD"

    // - Multiple products in a single event.
    if let products = properties["products"] as? [[String: Any]] {
      for var product in products {
        // - Retrieve fields
        // This SDK previously checked for `"productId"` but will now accept `"product_id"` as the first default, according to the Segment V2 spec.
        let productId =
          product["product_id"] as? String
            ?? product["productId"] as? String
            ?? "Unknown"
        let price = extractRevenue(key: "price", from: product) ?? 0
        let quantity = product["quantity"] as? Int
        // - Cleanup
        product["product_id"] = nil
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

  /// Logs a custom event in Braze with cleaned properties.
  ///
  /// This method forwards custom events to Braze, automatically removing revenue
  /// and currency properties to avoid conflicts with purchase tracking.
  ///
  /// - Parameters:
  ///   - name: The name of the custom event to log.
  ///   - properties: Optional event properties (revenue/currency are automatically removed).
  private func logCustomEvent(name: String, properties: [String: Any]?) {
    var properties = properties
    properties?["revenue"] = nil
    properties?["currency"] = nil
    braze?.logCustomEvent(name: name, properties: properties)
  }

  /// Extracts revenue value from event properties with type conversion.
  ///
  /// This method attempts to extract a numeric revenue value from event properties,
  /// handling both string and numeric representations.
  ///
  /// - Parameters:
  ///   - key: The property key to extract revenue from (e.g., "revenue", "price").
  ///   - properties: The event properties dictionary to search.
  /// - Returns: The extracted revenue as a `Double`, or `nil` if not found or invalid.
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

  /// Logs a message using the Segment Analytics logging system.
  ///
  /// This method provides consistent logging with a Braze-specific prefix for
  /// easy identification in debug logs.
  ///
  /// - Parameter message: The message to log.
  private func log(message: String) {
    analytics?.log(message: "[BrazeSegment] \(message)")
  }

  /// Prepares a dictionary to be sent to Braze by formatting nested structures.
  ///
  /// This method recursively processes dictionary values to ensure compatibility
  /// with Braze's expected data formats, handling nested objects and arrays.
  ///
  /// - Parameter jsonObject: The dictionary to format for Braze compatibility.
  /// - Returns: A formatted dictionary ready for Braze consumption.
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

  /// Formats an array by converting values to Braze-compatible types.
  ///
  /// This method processes array elements recursively, ensuring that nested structures
  /// are properly formatted while preserving string arrays and converting other types
  /// to their string representations.
  ///
  /// - Parameter jsonArray: The array to format for Braze compatibility.
  /// - Returns: A formatted array with Braze-compatible element types.
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

  /// Converts an array to string representations as a fallback formatting method.
  ///
  /// This method is used when an array doesn't match any of Braze's preferred formats
  /// and needs to be converted to a string array for compatibility.
  ///
  /// - Parameter jsonArray: The array to convert to strings.
  /// - Returns: An array of string representations of the input elements.
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
}

// MARK: - BrazeDestination Internal Extensions

extension BrazeDestination {
  /// Internal method to create Braze instance using factory
  private func createBrazeInstance(
    from settings: BrazeSettings,
    configuration: Braze.Configuration
  ) -> Braze {
    additionalConfiguration?(configuration)

    let brazeInstance = brazeFactory.createBraze(configuration: configuration)

    #if canImport(BrazeUI)
      if settings.automaticInAppMessageRegistrationEnabled == true {
        MainActor.synchronousRun {
          inAppMessageUI = brazeFactory.createInAppMessageUI()
          brazeInstance.inAppMessagePresenter = inAppMessageUI
        }
      }
    #endif

    MainActor.synchronousRun {
      additionalSetup?(brazeInstance)
    }

    return brazeInstance
  }

  /// Internal method to process user traits
  func processUserTraits(_ traits: [String: Any]) {
    // Birthday processing
    if let birthday = traits["birthday"] as? String {
      let dateformatter = DateFormatter()
      dateformatter.locale = Locale(identifier: "en_US_POSIX")
      dateformatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
      let formattedBirthday = dateformatter.date(from: birthday)
      braze?.user.set(dateOfBirth: formattedBirthday)
    }

    // Standard attributes
    if let email = traits["email"] as? String {
      braze?.user.set(email: email)
    }

    if let firstName = traits["firstName"] as? String {
      braze?.user.set(firstName: firstName)
    }

    if let lastName = traits["lastName"] as? String {
      braze?.user.set(lastName: lastName)
    }

    if let gender = (traits["gender"] as? String)?.lowercased() {
      processGender(gender)
    }

    if let phone = traits["phone"] as? String {
      braze?.user.set(phoneNumber: phone)
    }

    if let address = traits["address"] as? [String: Any] {
      if let city = address["city"] as? String {
        braze?.user.set(homeCity: city)
      }
      if let country = address["country"] as? String {
        braze?.user.set(country: country)
      }
    }

    // Subscription groups
    if let subscriptions = traits[Keys.subscriptionGroup.rawValue] as? [[String: Any]] {
      processSubscriptionGroups(subscriptions)
    }

    // Custom attributes
    processCustomAttributes(traits)
  }

  func processGender(_ gender: String) {
    if Keys.maleTokens.contains(gender) {
      braze?.user.set(gender: .male)
    } else if Keys.femaleTokens.contains(gender) {
      braze?.user.set(gender: .female)
    } else if Keys.notApplicableTokens.contains(gender) {
      braze?.user.set(gender: .notApplicable)
    } else if gender.lowercased() == "other" {
      braze?.user.set(gender: .other)
    } else if gender.lowercased() == "prefer not to say" {
      braze?.user.set(gender: .preferNotToSay)
    } else {
      braze?.user.set(gender: .unknown)
    }
  }

  /// Internal method to process subscription groups
  func processSubscriptionGroups(_ subscriptions: [[String: Any]]) {
    for subscription in subscriptions {
      guard
        let groupID = subscription[Keys.subscriptionId.rawValue] as? String,
        let groupState = subscription[Keys.subscriptionGroupState.rawValue] as? String
        ?? subscription[Keys.subscriptionStateId.rawValue] as? String
      else { continue }

      switch groupState {
      case "subscribed":
        braze?.user.addToSubscriptionGroup(id: groupID)
      case "unsubscribed":
        braze?.user.removeFromSubscriptionGroup(id: groupID)
      default:
        log(message: "Unsupported subscription state '\(groupState)' for group '\(groupID)'")
      }
    }
  }

  /// Internal method to process custom attributes
  func processCustomAttributes(_ traits: [String: Any]) {
    for trait in traits where !Keys.reservedKeys.contains(trait.key) {
      let key = trait.key
      switch trait.value {
      case let value as String:
        braze?.user.setCustomAttribute(key: key, value: value)
      case let value as Date:
        braze?.user.setCustomAttribute(key: key, value: value)
      case let value as Bool:
        braze?.user.setCustomAttribute(key: key, value: value)
      case let value as Int:
        braze?.user.setCustomAttribute(key: key, value: value)
      case let value as Double:
        braze?.user.setCustomAttribute(key: key, value: value)
      case let value as [String]:
        braze?.user.setCustomAttribute(key: key, array: value)
      case let value as [String: Any?]:
        braze?.user.setCustomAttribute(key: key, dictionary: formatDictionary(value))
      case let value as [[String: Any?]]:
        let formattedArray = value.map { formatDictionary($0) }
        braze?.user.setCustomAttribute(key: key, array: formattedArray)
      case let value as [Any?]:
        braze?.user.setCustomAttribute(key: key, array: castToStringArray(value))
      default:
        braze?.user.setCustomAttribute(key: key, value: String(describing: trait.value))
      }
    }
  }
}

// MARK: - Settings

extension BrazeDestination {
  struct BrazeSettings: Codable {
    let apiKey: String
    let customEndpoint: String?
    let automaticInAppMessageRegistrationEnabled: Bool?
    let logPurchaseWhenRevenuePresent: Bool?

    enum CodingKeys: String, CodingKey {
      case apiKey
      case customEndpoint
      case automaticInAppMessageRegistrationEnabled =
        "automatic_in_app_message_registration_enabled"
      case logPurchaseWhenRevenuePresent
    }
  }
}

// MARK: - Internal Constants

extension BrazeDestination {
  enum Keys: String {
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
