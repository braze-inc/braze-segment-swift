import Segment
import SwiftUI

struct ContentView: View {
  var body: some View {
    List {
      Section("Segment Actions") {
        Button("Track Purchase") {
          var traits = [String: Any]()
          var products = [Any]()
          products.append([
            "price": 1,
            "quantity": 1,
            "productId": "foo",
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
            "productId": "baz",
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
        Button("Identify") {
          var traits = [String: Any]()
          traits["birthday"] = "1980-06-07T01:21:13Z"
          traits["email"] = "testuser@test.com"
          traits["firstName"] = "fnu"
          traits["lastName"] = "lnu"
          traits["gender"] = "male"
          traits["phone"] = "1-234-5678"
          traits["address"] = ["city": "Paris", "country": "USA"]
          traits["foo"] = ["bar": "baz"]
          Analytics.main.identify(userId: "X-1234567890", traits: traits)
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
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
