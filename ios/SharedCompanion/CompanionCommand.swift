import AppIntents
import Foundation

extension Notification.Name {
  static let zingChartCompanionCommand = Notification.Name(
    "software.baycho.zmp3chart.companion.command"
  )
}

enum ZingChartCompanionCommandCenter {
  static let appGroup = "group.software.baycho.zmp3chart.shared"

  static func dispatch(_ action: String) {
    UserDefaults(suiteName: appGroup)?.set(action, forKey: "pendingCommand")
    NotificationCenter.default.post(
      name: .zingChartCompanionCommand,
      object: nil,
      userInfo: ["action": action]
    )
  }
}

@available(iOS 17.0, *)
struct ZingChartPlaybackIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Điều khiển #zingChart"
  static var description = IntentDescription("Điều khiển nhạc đang phát trên #zingChart.")

  @Parameter(title: "Lệnh") var action: String

  init() {
    action = "togglePlayPause"
  }

  init(action: String) {
    self.action = action
  }

  func perform() async throws -> some IntentResult {
    ZingChartCompanionCommandCenter.dispatch(action)
    return .result()
  }
}
