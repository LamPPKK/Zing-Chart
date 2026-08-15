import SwiftUI
import WidgetKit

private struct MacPlayerEntry: TimelineEntry {
  let date: Date
  let title: String
  let artist: String
  let isPlaying: Bool
  let positionMs: Int
  let durationMs: Int
  let updatedAtMs: Int

  static func current() -> MacPlayerEntry {
    let values = UserDefaults(
      suiteName: ZingChartMacCompanionCommandCenter.appGroup
    )?.dictionary(forKey: "playerSnapshot") ?? [:]
    let position = values["positionMs"] as? Int ?? 0
    let duration = values["durationMs"] as? Int ?? 0
    return MacPlayerEntry(
      date: .now,
      title: values["title"] as? String ?? "#zingChart",
      artist: values["artist"] as? String ?? macLocalized(
        vi: "Chưa chọn bài hát",
        en: "Choose a song in the app",
        zh: "请在应用中选择歌曲"
      ),
      isPlaying: values["isPlaying"] as? Bool ?? false,
      positionMs: position,
      durationMs: duration,
      updatedAtMs: values["updatedAtMs"] as? Int ?? 0
    )
  }

  var currentPositionMs: Int {
    guard isPlaying, updatedAtMs > 0 else { return positionMs }
    let nowMs = Int(Date.now.timeIntervalSince1970 * 1000)
    return min(durationMs, positionMs + max(0, nowMs - updatedAtMs))
  }

  var progress: Double {
    guard durationMs > 0 else { return 0 }
    return min(1, max(0, Double(currentPositionMs) / Double(durationMs)))
  }

  var timerInterval: ClosedRange<Date> {
    let start = Date.now.addingTimeInterval(-Double(currentPositionMs) / 1000)
    return start...start.addingTimeInterval(Double(durationMs) / 1000)
  }
}

private struct MacPlayerProvider: TimelineProvider {
  func placeholder(in context: Context) -> MacPlayerEntry { .current() }
  func getSnapshot(in context: Context, completion: @escaping (MacPlayerEntry) -> Void) {
    completion(.current())
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<MacPlayerEntry>) -> Void) {
    completion(Timeline(entries: [.current()], policy: .never))
  }
}

private struct MacPlayerWidgetView: View {
  let entry: MacPlayerEntry

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [.black, Color(red: 0.14, green: 0.13, blue: 0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      VStack(alignment: .leading, spacing: 11) {
        HStack(spacing: 10) {
          RoundedRectangle(cornerRadius: 13)
            .fill(LinearGradient(
              colors: [Color(red: 1, green: 0.42, blue: 0.37),
                       Color(red: 0.85, green: 1, blue: 0.28)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
            .frame(width: 42, height: 42)
            .overlay(Image(systemName: "waveform").foregroundStyle(.black))
          VStack(alignment: .leading, spacing: 2) {
            Text(entry.title).font(.headline).lineLimit(1)
            Text(entry.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          }
        }
        playbackProgress
        HStack {
          button(
            "backward.end.fill",
            "previous",
            label: macLocalized(vi: "Bài trước", en: "Previous", zh: "上一首")
          )
          Spacer()
          button(
            entry.isPlaying ? "pause.fill" : "play.fill",
            "togglePlayPause",
            label: entry.isPlaying
              ? macLocalized(vi: "Tạm dừng", en: "Pause", zh: "暂停")
              : macLocalized(vi: "Phát", en: "Play", zh: "播放"),
            prominent: true
          )
          Spacer()
          button(
            "forward.end.fill",
            "next",
            label: macLocalized(vi: "Bài tiếp", en: "Next", zh: "下一首")
          )
        }
      }
      .padding(16)
    }
    .containerBackground(.clear, for: .widget)
  }

  @ViewBuilder
  private var playbackProgress: some View {
    if entry.isPlaying && entry.durationMs > 0 {
      ProgressView(timerInterval: entry.timerInterval, countsDown: false)
        .tint(Color(red: 1, green: 0.42, blue: 0.37))
    } else {
      ProgressView(value: entry.progress)
        .tint(Color(red: 1, green: 0.42, blue: 0.37))
    }
  }

  private func button(
    _ symbol: String,
    _ action: String,
    label: String,
    prominent: Bool = false
  ) -> some View {
    Button(intent: ZingChartMacPlaybackIntent(action: action)) {
      Image(systemName: symbol)
        .frame(width: 32, height: 32)
        .background(prominent ? Color.white : Color.clear, in: Circle())
        .foregroundStyle(prominent ? Color.black : Color.white)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

private func macLocalized(vi: String, en: String, zh: String) -> String {
  let language = Locale.current.language.languageCode?.identifier ?? "vi"
  if language == "zh" { return zh }
  if language == "en" { return en }
  return vi
}

@main
struct ZingChartMacWidgetBundle: WidgetBundle {
  var body: some Widget {
    StaticConfiguration(kind: "ZingChartNowPlayingMac", provider: MacPlayerProvider()) {
      MacPlayerWidgetView(entry: $0)
    }
    .configurationDisplayName("#zingChart")
    .description(macLocalized(
      vi: "Xem và điều khiển bài hát đang phát.",
      en: "See and control the song playing now.",
      zh: "查看并控制当前播放的歌曲。"
    ))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
