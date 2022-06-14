//
//  BrazeDestination.swift
//  BrazeDestination
//
//  Created by Michael Grosse Huelsewiesche on 5/17/22.
//

// NOTE: You can see this plugin in use in the BasicExample application.
//

// MIT License
//
// Copyright (c) 2022 Segment
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Segment
import BrazeKit
import UIKit

/**
 An implementation of the Braze Analytics device mode destination as a plugin.
 */

public class BrazeDestination: DestinationPlugin {
    public let timeline = Timeline()
    public let type = PluginType.destination
    public let key = "Appboy"
    public var analytics: Analytics? = nil
    var braze: Braze? = nil
    
    private var brazeSettings: BrazeSettings?
        
    public init() { }
    
    public func update(settings: Settings, type: UpdateType) {
        // Skip if you have a singleton and don't want to keep updating via settings.
        guard type == .initial else { return }
        
        // Grab the settings and assign them for potential later usage.
        // Note: Since integrationSettings is generic, strongly type the variable.
        guard let tempSettings: BrazeSettings = settings.integrationSettings(forPlugin: self) else { return }
        brazeSettings = tempSettings
        
        let configuration = Braze.Configuration(
            apiKey: brazeSettings?.apiKey ?? "",
            endpoint: brazeSettings?.customEndpoint ?? ""
            )
        braze = Braze(configuration: configuration)
    }
    
    public func identify(event: IdentifyEvent) -> IdentifyEvent? {
        
        if let userId = event.userId, !userId.isEmpty {
            braze?.changeUser(userId: userId)
        }

        if let traits = event.traits?.dictionaryValue {
            if let birthday = traits["birthday"] as? String {
                let dateformatter = DateFormatter()
                dateformatter.locale = Locale(identifier: "en_US_POSIX")
                dateformatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ" // RFC3339 format date
                let formattedBirthday = dateformatter.date(from: birthday)
                braze?.user.set(dateOfBirth: formattedBirthday)
            }
            
            if let email = traits["email"] as? String {
                braze?.user.set(email: email)
            }

            if let firstName = traits["firstName"] as? String {
                braze?.user.set(firstName: firstName)
            }

            if let lastName = traits["lastName"] as? String {
                braze?.user.set(lastName: lastName)
            }
            
            if let gender = traits["gender"] as? String {
                if gender.lowercased() == "m" || gender.lowercased() == "male" {
                    braze?.user.set(gender: Braze.User.Gender.male)
                }
                else if gender.lowercased() == "f" || gender.lowercased() == "female" {
                    braze?.user.set(gender: Braze.User.Gender.female)
                }
                else if gender.lowercased() == "na" || gender.lowercased() == "not applicable" {
                    braze?.user.set(gender: Braze.User.Gender.notApplicable)
                }
                else if gender.lowercased() == "other" {
                    braze?.user.set(gender: Braze.User.Gender.other)
                }
                else if gender.lowercased() == "prefer not to say" {
                    braze?.user.set(gender: Braze.User.Gender.preferNotToSay)
                }
                else {
                    braze?.user.set(gender: Braze.User.Gender.unknown)
                }
            }
            
            if let phone = traits["phone"] as? String {
                braze?.user.set(phoneNumber: phone)
            }
            
            if let address = traits["address"] as? Dictionary<String, Any> {
                if let city = address["city"] as? String {
                    braze?.user.set(homeCity: city)
                }
                if let country = address["country"] as? String {
                    braze?.user.set(country: country)
                }
            }
            
            let brazeTraits = ["birthday", "email", "firstName", "lastName", "gender", "phone", "address", "anonymousID"]
            
            for trait in traits where !brazeTraits.contains(trait.key) {
                switch trait.value {
                case let val as String:
                    braze?.user.setCustomAttribute(key: trait.key, value: val)
                case let val as Date:
                    braze?.user.setCustomAttribute(key: trait.key, value: val)
                case let val as Bool:
                    braze?.user.setCustomAttribute(key: trait.key, value: val)
                case let val as Int:
                    braze?.user.setCustomAttribute(key: trait.key, value: val)
                case let val as Double:
                    braze?.user.setCustomAttribute(key: trait.key, value: val)
                case let val as Array<String>:
                    braze?.user.setCustomAttributeArray(key: trait.key, array: val)
                default:
                    braze?.user.setCustomAttribute(key: trait.key, value: String(describing: trait.value))
                }
            }
        }

        return event
    }
    
    public func track(event: TrackEvent) -> TrackEvent? {
        let properties = event.properties?.dictionaryValue
        let revenue = self.extractRevenue(key: "revenue", from: properties)
        if (revenue != nil && revenue != 0) || event.event == "Order Completed" || event.event == "Completed Order" {
            let currency = properties?["currency"] as? String ?? "USD"
            
            if properties != nil {
                var appboyProperties = properties!
                appboyProperties["currency"] = nil
                appboyProperties["revenue"] = nil
                if let products = appboyProperties["products"] as? Array<Any> {
                    appboyProperties["products"] = nil
                    for product in products {
                        var productDict = product as? Dictionary<String, Any>
                        let productId = productDict?["productId"] as? String ?? "Unknown"
                        let productRevenue = self.extractRevenue(key: "price", from: productDict)
                        let productQuantity = productDict?["quantity"] as? Int
                        productDict?["productId"] = nil
                        productDict?["price"] = nil
                        productDict?["quantity"] = nil
                        var productProperties = appboyProperties
                        if let productDict = productDict {
                            productProperties.merge(productDict, uniquingKeysWith: { (_, new) in new } )
                        }
                        braze?.logPurchase(productId: productId,
                                           currency: currency,
                                           price: productRevenue ?? 0,
                                           quantity: productQuantity ?? 0,
                                           properties: productProperties)
                    }
                } else {
                    braze?.logPurchase(productId: event.event,
                                       currency: currency,
                                       price: revenue ?? 0,
                                       quantity: 1,
                                       properties: appboyProperties)
                }
            } else {
                braze?.logPurchase(productId: event.event,
                                   currency: currency,
                                   price: revenue ?? 0,
                                   quantity: 1)
            }
        }
        return event
    }
}

extension BrazeDestination: VersionedPlugin {
    public static func version() -> String {
        return __destination_version
    }
}

private struct BrazeSettings: Codable {
    let sessionTimeoutInSeconds: Double?
    let doNotLoadFontAwesome: Bool?
    let safariWebsitePushId: String?
    let enableLogging: Bool?
    let restCustomEndpoint: String?
    let version: String?
    let type: String?
    let onlyTrackKnownUsersOnWeb: Bool?
    let openInAppMessagesInNewTab: Bool?
    let trackAllPages: Bool?
    let trackNamedPages: Bool?
    let apiKey: String
    let customEndpoint: String?
    let logPurchaseWhenRevenuePresent: Bool?
    let automaticallyDisplayMessages: Bool?
    let updateExistingOnly: Bool?
    let automatic_in_app_message_registration_enabled: Bool?
    let localization: String?
    let openNewsFeedCardsInNewTab: Bool?
    let datacenter: String
    let minimumIntervalBetweenTriggerActionsInSeconds: Double?
    let allowCrawlerActivity: Bool?
    let enableHtmlInAppMessages: Bool?
//    let versionSettings: Dictionary<String, Any?> // not Codable
    let bundlingStatus: String?
    let serviceWorkerLocation: String?
    let requireExplicitInAppMessageDismissal: Bool?

    
}

extension BrazeDestination {
    internal func extractRevenue(key: String, from properties: [String: Any]?) -> Double? {
        
        if let revenueDouble =  properties?[key] as? Double {
            return revenueDouble
        }
        
        if let revenueString = properties?[key] as? String  {
            let revenueDouble = Double(revenueString)
            return revenueDouble
        }
        
        return nil
    }
    
    
    internal func extractCurrency(key: String, from properties: [String: Any]?, withDefault value: String? = nil) -> String? {
        
        if let currency = properties?[key] as? String {
            return currency
        }
        
        return "USD"
    }
    
}
    
// Rules for converting keys and values to the proper formats that bridge
// from Segment to the Partner SDK. These are only examples.
private extension BrazeDestination {
    
    static var eventNameMap = ["ADD_TO_CART": "Product Added",
                               "PRODUCT_TAPPED": "Product Tapped"]
    
    static var eventValueConversion: ((_ key: String, _ value: Any) -> Any) = { (key, value) in
        if let valueString = value as? String {
            return valueString
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: " ", with: "_")
        } else {
            return value
        }
    }
}
