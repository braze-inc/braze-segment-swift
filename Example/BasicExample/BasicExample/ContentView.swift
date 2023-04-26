//
//  ContentView.swift
//  BasicExample
//
//  Created by Brandon Sneed on 2/23/22.
//

import SwiftUI
import Segment

struct ContentView: View {
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    var traits = [String:Codable]()
                    var products = [Any]()
                    products.append(["price":1,"quantity":1,"productId":"foo","color":"blue", "dupe":"override"])
                    products.append(["price":2,"quantity":2,"productId":"bar","size":"large"])
                    products.append(["price":3,"quantity":3,"productId":"baz","fit":9])
                    let productStr = convertIntoJSONString(arrayObject: products)
                    traits["products"] = productStr
                    traits["dupe"] = "default"
                    traits["general"] = "value"
                    Analytics.main.track(name: "Order Completed", properties: traits)
                }, label: {
                    Text("Track")
                }).padding(6)
                Button(action: {
                    Analytics.main.screen(title: "Screen appeared")
                }, label: {
                    Text("Screen")
                }).padding(6)
            }.padding(8)
            HStack {
                Button(action: {
                    Analytics.main.group(groupId: "12345-Group")
                    Analytics.main.log(message: "Started group")
                }, label: {
                    Text("Group")
                }).padding(6)
                Button(action: {
                    var traits = [String:Codable]()
                    traits["birthday"] = "1980-06-07T01:21:13Z"
                    traits["email"] = "testuser@test.com"
                    traits["firstName"] = "fnu"
                    traits["lastName"] = "lnu"
                    traits["gender"] = "male"
                    traits["phone"] = "1-234-5678"
                    traits["address"] = ["city": "Paris", "country": "USA"]
                    traits["foo"] = ["bar": "baz"]
                    Analytics.main.identify(userId: "X-1234567890", traits: traits)
                }, label: {
                    Text("Identify")
                }).padding(6)
            }.padding(8)
        }.onAppear {
            Analytics.main.track(name: "onAppear")
            print("Executed Analytics onAppear()")
        }.onDisappear {
            Analytics.main.track(name: "onDisappear")
            print("Executed Analytics onDisappear()")
        }
    }
    
    func convertIntoJSONString(arrayObject: [Any]) -> String? {

            do {
                let jsonData: Data = try JSONSerialization.data(withJSONObject: arrayObject, options: [])
                if  let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue) {
                    return jsonString as String
                }
                
            } catch let error as NSError {
                print("Array convertIntoJSON - \(error.description)")
            }
            return nil
        }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
