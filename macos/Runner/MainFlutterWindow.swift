import Cocoa
import FlutterMacOS
import WidgetKit

class MainFlutterWindow: NSWindow {
  private var companionChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    (NSApp.delegate as? AppDelegate)?.configureDeepLinkChannel(flutterViewController)
    let channel = FlutterMethodChannel(
      name: "software.baycho.zmp3chart/companion",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "publishSnapshot",
            let values = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      let snapshot = values.filter { !($0.value is NSNull) }
      let defaults = UserDefaults(suiteName: ZingChartMacCompanionCommandCenter.appGroup)
      let widgetSignature = [
        snapshot["songId"] as? String ?? "",
        snapshot["status"] as? String ?? "idle",
        String(describing: snapshot["durationMs"] ?? 0)
      ].joined(separator: "|")
      let shouldReloadWidget = defaults?.string(forKey: "widgetSignature") != widgetSignature
      defaults?.set(snapshot, forKey: "playerSnapshot")
      defaults?.set(widgetSignature, forKey: "widgetSignature")
      if #available(macOS 14.0, *), shouldReloadWidget {
        WidgetCenter.shared.reloadTimelines(ofKind: "ZingChartNowPlayingMac")
      }
      result(nil)
    }
    companionChannel = channel
    NotificationCenter.default.addObserver(
      forName: .zingChartMacCompanionCommand,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let action = notification.userInfo?["action"] as? String else { return }
      UserDefaults(suiteName: ZingChartMacCompanionCommandCenter.appGroup)?
        .removeObject(forKey: "pendingCommand")
      self?.companionChannel?.invokeMethod("command", arguments: ["action": action])
    }
    if let defaults = UserDefaults(suiteName: ZingChartMacCompanionCommandCenter.appGroup),
       let action = defaults.string(forKey: "pendingCommand") {
      defaults.removeObject(forKey: "pendingCommand")
      channel.invokeMethod("command", arguments: ["action": action])
    }

    super.awakeFromNib()
  }
}
