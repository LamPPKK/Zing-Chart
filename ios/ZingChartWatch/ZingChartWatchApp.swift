import SwiftUI

@main
struct ZingChartWatchApp: App {
  @StateObject private var session = WatchSessionModel()

  var body: some Scene {
    WindowGroup {
      WatchPlayerView().environmentObject(session)
    }
  }
}
