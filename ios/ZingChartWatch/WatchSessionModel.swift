import Foundation
import WatchConnectivity

@MainActor
final class WatchSessionModel: NSObject, ObservableObject {
  @Published var title = "#zingChart"
  @Published var artist = ""
  @Published var isPlaying = false
  @Published var positionMs = 0
  @Published var durationMs = 0
  @Published var updatedAtMs = 0
  @Published var isReachable = false

  override init() {
    super.init()
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
    apply(session.applicationContext)
  }

  func send(_ action: String) {
    guard WCSession.default.isReachable else {
      isReachable = false
      return
    }
    WCSession.default.sendMessage(["action": action], replyHandler: nil) { [weak self] _ in
      Task { @MainActor in self?.isReachable = false }
    }
  }

  func progress(at date: Date) -> Double {
    guard durationMs > 0 else { return 0 }
    let elapsed = isPlaying ? max(0, Int(date.timeIntervalSince1970 * 1000) - updatedAtMs) : 0
    return min(1, max(0, Double(positionMs + elapsed) / Double(durationMs)))
  }

  private func apply(_ values: [String: Any]) {
    title = values["title"] as? String ?? "#zingChart"
    artist = values["artist"] as? String ?? localized(
      vi: "Chọn bài hát trên điện thoại",
      en: "Choose a song on your phone",
      zh: "请在手机上选择歌曲"
    )
    isPlaying = values["isPlaying"] as? Bool ?? false
    positionMs = values["positionMs"] as? Int ?? 0
    durationMs = values["durationMs"] as? Int ?? 0
    updatedAtMs = values["updatedAtMs"] as? Int ?? 0
  }
}

extension WatchSessionModel: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      isReachable = session.isReachable
      apply(session.applicationContext)
    }
  }

  nonisolated func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    Task { @MainActor in apply(applicationContext) }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in isReachable = session.isReachable }
  }
}

func localized(vi: String, en: String, zh: String) -> String {
  let language = Locale.current.language.languageCode?.identifier ?? "vi"
  if language == "zh" { return zh }
  if language == "en" { return en }
  return vi
}
