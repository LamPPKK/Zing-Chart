import UIKit
import Flutter
import WatchConnectivity
import WidgetKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {
  private let companionChannelName = "software.baycho.zmp3chart/companion"
  private let appGroup = "group.software.baycho.zmp3chart.shared"
  private var companionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: companionChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "publishSnapshot",
              let values = call.arguments as? [String: Any] else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.publishCompanionSnapshot(values)
        result(nil)
      }
      companionChannel = channel
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(receiveCompanionCommand(_:)),
      name: .zingChartCompanionCommand,
      object: nil
    )
    activateWatchSession()
    consumePendingCompanionCommand()
    return launched
  }

  private func publishCompanionSnapshot(_ values: [String: Any]) {
    let snapshot = values.filter { !($0.value is NSNull) }
    let defaults = UserDefaults(suiteName: appGroup)
    let widgetSignature = [
      snapshot["songId"] as? String ?? "",
      snapshot["status"] as? String ?? "idle",
      String(describing: snapshot["durationMs"] ?? 0)
    ].joined(separator: "|")
    let shouldReloadWidget = defaults?.string(forKey: "widgetSignature") != widgetSignature
    defaults?.set(snapshot, forKey: "playerSnapshot")
    defaults?.set(widgetSignature, forKey: "widgetSignature")
    if #available(iOS 14.0, *), shouldReloadWidget {
      WidgetCenter.shared.reloadTimelines(ofKind: "ZingChartNowPlaying")
    }
    guard WCSession.isSupported(), WCSession.default.activationState == .activated else {
      return
    }
    do {
      try WCSession.default.updateApplicationContext(snapshot)
    } catch {
      // Watch sync is optional and must never interrupt phone playback.
    }
  }

  private func activateWatchSession() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  @objc private func receiveCompanionCommand(_ notification: Notification) {
    guard let action = notification.userInfo?["action"] as? String else { return }
    dispatchCompanionCommand(action)
  }

  private func consumePendingCompanionCommand() {
    guard let defaults = UserDefaults(suiteName: appGroup),
          let action = defaults.string(forKey: "pendingCommand") else { return }
    defaults.removeObject(forKey: "pendingCommand")
    dispatchCompanionCommand(action)
  }

  private func dispatchCompanionCommand(_ action: String) {
    UserDefaults(suiteName: appGroup)?.removeObject(forKey: "pendingCommand")
    DispatchQueue.main.async { [weak self] in
      self?.companionChannel?.invokeMethod("command", arguments: ["action": action])
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard let action = message["action"] as? String else { return }
    dispatchCompanionCommand(action)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any],
               replyHandler: @escaping ([String: Any]) -> Void) {
    guard let action = message["action"] as? String else {
      replyHandler(["accepted": false])
      return
    }
    dispatchCompanionCommand(action)
    replyHandler(["accepted": true])
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
