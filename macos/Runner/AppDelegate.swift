import Cocoa
import FlutterMacOS

final class ZingChartDeepLinkQueue {
  private(set) var pendingURL: URL?

  func enqueue(_ url: URL) {
    pendingURL = url
  }

  func take() -> URL? {
    defer { pendingURL = nil }
    return pendingURL
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private let deepLinkQueue = ZingChartDeepLinkQueue()
  private var deepLinkChannel: FlutterMethodChannel?
  private var dartIsReady = false

  override func application(_ application: NSApplication, open urls: [URL]) {
    super.application(application, open: urls)
    guard let url = urls.last(where: { $0.scheme?.lowercased() == "zingchart" }) else { return }
    deepLinkQueue.enqueue(url)
    flushPendingURLIfReady()
  }

  func configureDeepLinkChannel(_ controller: FlutterViewController) {
    guard deepLinkChannel == nil else { return }
    let channel = FlutterMethodChannel(
      name: "software.baycho.zmp3chart/deep_link",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "getInitialRoute":
        result(self.deepLinkQueue.take()?.absoluteString)
      case "ready":
        self.dartIsReady = true
        result(nil)
        self.flushPendingURLIfReady()
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    deepLinkChannel = channel
  }

  private func flushPendingURLIfReady() {
    guard dartIsReady,
          let channel = deepLinkChannel,
          let url = deepLinkQueue.take() else { return }
    channel.invokeMethod("open", arguments: ["route": url.absoluteString])
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
