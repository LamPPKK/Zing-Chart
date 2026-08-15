import SwiftUI

struct WatchPlayerView: View {
  @EnvironmentObject private var session: WatchSessionModel

  var body: some View {
    VStack(spacing: 9) {
      Text(session.isReachable
           ? localized(vi: "ĐÃ KẾT NỐI", en: "CONNECTED", zh: "已连接")
           : localized(vi: "MỞ APP ĐIỆN THOẠI", en: "OPEN PHONE APP", zh: "打开手机应用"))
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .tracking(1.2)
        .foregroundStyle(session.isReachable ? Color.limeSignal : .secondary)
      VStack(spacing: 2) {
        Text(session.title).font(.headline).lineLimit(1)
        Text(session.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
      }
      TimelineView(.periodic(from: .now, by: 1)) { context in
        ProgressView(value: session.progress(at: context.date))
          .tint(.coralSignal)
      }
      HStack(spacing: 12) {
        control("backward.end.fill", label: localized(vi: "Bài trước", en: "Previous", zh: "上一首")) {
          session.send("previous")
        }
        control(
          session.isPlaying ? "pause.fill" : "play.fill",
          label: session.isPlaying
            ? localized(vi: "Tạm dừng", en: "Pause", zh: "暂停")
            : localized(vi: "Phát", en: "Play", zh: "播放"),
          prominent: true
        ) {
          session.send("togglePlayPause")
        }
        control("forward.end.fill", label: localized(vi: "Bài tiếp", en: "Next", zh: "下一首")) {
          session.send("next")
        }
      }
    }
    .padding(.horizontal, 9)
    .containerBackground(
      LinearGradient(
        colors: [.black, Color(red: 0.14, green: 0.13, blue: 0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      for: .navigation
    )
  }

  private func control(
    _ symbol: String,
    label: String,
    prominent: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .frame(width: 34, height: 34)
        .background(prominent ? Color.white : Color.white.opacity(0.1), in: Circle())
        .foregroundStyle(prominent ? Color.black : Color.white)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

private extension Color {
  static let coralSignal = Color(red: 1, green: 0.42, blue: 0.37)
  static let limeSignal = Color(red: 0.85, green: 1, blue: 0.28)
}
