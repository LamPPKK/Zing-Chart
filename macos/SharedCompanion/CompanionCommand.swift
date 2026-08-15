import AppIntents
import Foundation

extension Notification.Name {
  static let zingChartMacCompanionCommand = Notification.Name(
    "software.baycho.zmp3chart.macos.companion.command"
  )
}

enum ZingChartMacCompanionCommandCenter {
  static let appGroup = "group.software.baycho.zmp3chart.shared"

  static func dispatch(_ action: String) {
    UserDefaults(suiteName: appGroup)?.set(action, forKey: "pendingCommand")
    NotificationCenter.default.post(
      name: .zingChartMacCompanionCommand,
      object: nil,
      userInfo: ["action": action]
    )
  }
}

@available(macOS 14.0, *)
struct ZingChartMacPlaybackIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Điều khiển #zingChart"
  @Parameter(title: "Lệnh") var action: String

  init() {
    action = "togglePlayPause"
  }

  init(action: String) {
    self.action = action
  }

  func perform() async throws -> some IntentResult {
    ZingChartMacCompanionCommandCenter.dispatch(action)
    return .result()
  }
}
