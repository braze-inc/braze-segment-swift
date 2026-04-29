import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
  @main
  struct SwiftyLiveActivityBundle: WidgetBundle {
    var body: some Widget {
      SwiftyWidget()
      SwiftyLiveActivity()
    }
  }
#endif
