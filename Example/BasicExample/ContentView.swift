import Segment
import SwiftUI

struct ContentView: View {
  @State private var userId: String = ""

  var body: some View {
    List {
      Section("Identify Action") {
        TextField("User ID", text: $userId)
          .autocapitalization(.none)
          .disableAutocorrection(true)

        Button("Identify without traits") {
          guard userId != "" else {
            print("Provide a User id to call the `Identify` action.")
            return
          }
          Analytics.main.identify(userId: userId)
        }
        Button("Identify with traits") {
          guard userId != "" else {
            print("Provide a User id to call the `Identify` action.")
            return
          }
          var traits = [String: Any]()
          traits["birthday"] = "1980-06-07T01:21:13Z"
          traits["email"] = "testuser@test.com"
          traits["firstName"] = "fnu"
          traits["lastName"] = "lnu"
          traits["gender"] = "male"
          traits["phone"] = "1-234-5678"
          traits["address"] = ["city": "Paris", "country": "USA"]
          traits["foo"] = ["bar": "baz"]
          traits["braze_subscription_groups"] = [
            [
              "subscription_group_id": "1234",
              "subscription_group_state": "subscribed"
            ],
            [
              "subscription_group_id": "2234",
              "subscription_group_state": "unsubscribed"
            ]
          ]
          traits["any_array"] = [
            10,
            false,
            "string_item"
          ]
          traits["nested_object"] = [
            "prop_1": "default",
            "prop_2": true,
            "prop_3": 1.0,
            "nested_array": [
              "string",
              1.8,
              true
            ],
            "string_array": [
              "string1",
              "string2",
              "string3"
            ],
            "double_nested_object": [
              "very_nested1": "nest",
              "very_nested2": 2.5,
              "very_nested_array": [
                1,
                2,
                3
              ]
            ]
          ]
          traits["nested_object_array"] = [
            [
              "array_obj1": true,
              "array_obj2": "name"
            ],
            [
              "array_obj3": 1.5,
              "array_array": [
                2.3,
                "string",
                false,
                [
                  28,
                  27,
                  false
                ],
                [
                  "object1": "name",
                  "object2": 2.1,
                  "nested_array": [
                    25.2,
                    26.1
                  ]
                ]
              ]
            ]
          ]
          Analytics.main.identify(userId: userId, traits: traits)
        }
      }

      Section("SDK authentication") {
        Text("Uses the User ID field in Identify Action. If it is empty, the current Segment user is used when available.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("Identify — sample traits + SDK auth") {
          let signature = Self.randomSdkAuthSignature()
          let traits = Self.buildSampleIdentifyTraits(
            includeSdkAuthSignature: true,
            sdkAuthSignature: signature
          )
          let typedId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
          if !typedId.isEmpty {
            Analytics.main.identify(userId: typedId, traits: traits)
            print("Identify (SDK auth) userId=\(typedId) braze_sdk_auth_signature=\(signature)")
          } else if let current = Analytics.main.userId, !current.isEmpty {
            Analytics.main.identify(userId: current, traits: traits)
            print("Identify (SDK auth) userId=\(current) (from Segment) braze_sdk_auth_signature=\(signature)")
          } else {
            print(
              "Identify (SDK auth): enter a User ID in Identify Action, or identify once so a current user exists."
            )
          }
        }

        Button("Update SDK auth signature only") {
          let signature = Self.randomSdkAuthSignature()
          Analytics.main.identify(traits: ["braze_sdk_auth_signature": signature])
        }
      }

      Section("Other Segment Actions") {
        Button("Track Purchase") {
          var traits = [String: Any]()
          var products = [Any]()
          products.append([
            "price": 1,
            "quantity": 1,
            "product_id": "foo",
            "color": "blue",
            "dupe": "override",
          ] as [String : Any])
          products.append([
            "price": 2,
            "quantity": 2,
            "productId": "bar",
            "size": "large"
          ] as [String : Any])
          products.append([
            "price": 3,
            "quantity": 3,
            "product_id": "baz",
            "productId": "foo",
            "fit": 9
          ] as [String : Any])
          traits["products"] = products
          traits["dupe"] = "default"
          traits["general"] = "value"
          traits["revenue"] = 14.0
          Analytics.main.track(name: "Order Completed", properties: traits)
        }
        Button("Track Custom Event") {
          let properties: [String: Any] = [
            "foo": "baz",
            "count": 15,
            "correct": false
          ]
          Analytics.main.track(name: "braze-custom-event", properties: properties)
        }
        Button("Screen") {
          Analytics.main.screen(title: "Screen appeared")
        }
        Button("Group") {
          Analytics.main.group(groupId: "12345-Group")
          Analytics.main.log(message: "Started group")
        }
      }
    }
    .onAppear {
      Analytics.main.track(name: "onAppear")
      print("Executed Analytics onAppear()")
    }
    .onDisappear {
      Analytics.main.track(name: "onDisappear")
      print("Executed Analytics onDisappear()")
    }
  }

  private static func randomSdkAuthSignature() -> String {
    String(Int.random(in: 0..<100))
  }

  private static func buildSampleIdentifyTraits(
    includeSdkAuthSignature: Bool,
    sdkAuthSignature: String = ""
  ) -> [String: Any] {
    var traits = [String: Any]()
    if includeSdkAuthSignature, !sdkAuthSignature.isEmpty {
      traits["braze_sdk_auth_signature"] = sdkAuthSignature
    }
    traits["username"] = "BobBraze"
    traits["email"] = "bob@test.com"
    traits["plan"] = "premium"
    traits["testArray"] = ["test", 3, true] as [Any]
    let skillInfo: [String: Any] = [
      "certified": true,
      "languages": ["Swift", "Java", 1, false] as [Any],
    ]
    traits["jobInfo"] = [
      "department": "G9D",
      "office": "030-2 E208",
      "skillInfo": skillInfo,
    ] as [String: Any]
    return traits
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
