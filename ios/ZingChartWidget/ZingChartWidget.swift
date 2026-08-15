import SwiftUI
import WidgetKit

private struct PlayerSnapshot {
  let title: String
  let artist: String
  let isPlaying: Bool
  let positionMs: Int
  let durationMs: Int
  let updatedAtMs: Int

  static func load() -> PlayerSnapshot {
    let values = UserDefaults(
      suiteName: ZingChartCompanionCommandCenter.appGroup
    )?.dictionary(forKey: "playerSnapshot") ?? [:]
    return PlayerSnapshot(
      title: values["title"] as? String ?? "#zingChart",
      artist: values["artist"] as? String ?? localized(
        vi: "Chưa chọn bài hát",
        en: "Choose a song in the app",
        zh: "请在应用中选择歌曲"
      ),
      isPlaying: values["isPlaying"] as? Bool ?? false,
      positionMs: values["positionMs"] as? Int ?? 0,
      durationMs: values["durationMs"] as? Int ?? 0,
      updatedAtMs: values["updatedAtMs"] as? Int ?? 0
    )
  }

  var progress: Double {
    guard durationMs > 0 else { return 0 }
    return min(1, max(0, Double(currentPositionMs) / Double(durationMs)))
  }

  var currentPositionMs: Int {
    guard isPlaying, updatedAtMs > 0 else { return positionMs }
    let nowMs = Int(Date.now.timeIntervalSince1970 * 1000)
    return min(durationMs, positionMs + max(0, nowMs - updatedAtMs))
  }

  var timerInterval: ClosedRange<Date> {
    let start = Date.now.addingTimeInterval(-Double(currentPositionMs) / 1000)
    return start...start.addingTimeInterval(Double(durationMs) / 1000)
  }
}

private struct PlayerEntry: TimelineEntry {
  let date: Date
  let player: PlayerSnapshot
}

private struct PlayerProvider: TimelineProvider {
  func placeholder(in context: Context) -> PlayerEntry {
    PlayerEntry(date: .now, player: .load())
  }

  func getSnapshot(in context: Context, completion: @escaping (PlayerEntry) -> Void) {
    completion(PlayerEntry(date: .now, player: .load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PlayerEntry>) -> Void) {
    let entry = PlayerEntry(date: .now, player: .load())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

private struct PlayerWidgetView: View {
  let entry: PlayerEntry

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.07, green: 0.07, blue: 0.07),
                 Color(red: 0.14, green: 0.13, blue: 0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      VStack(alignment: .leading, spacing: 9) {
        HStack(spacing: 8) {
          RoundedRectangle(cornerRadius: 11)
            .fill(
              LinearGradient(
                colors: [Color(red: 1, green: 0.42, blue: 0.37),
                         Color(red: 0.85, green: 1, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 34, height: 34)
            .overlay(Image(systemName: "waveform").foregroundStyle(.black))
          VStack(alignment: .leading, spacing: 2) {
            Text(entry.player.title).font(.headline).lineLimit(1)
            Text(entry.player.artist)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        playbackProgress
        HStack {
          control("backward.end.fill", action: "previous", label: previousLabel)
          Spacer()
          control(
            entry.player.isPlaying ? "pause.fill" : "play.fill",
            action: "togglePlayPause",
            label: entry.player.isPlaying ? pauseLabel : playLabel,
            prominent: true
          )
          Spacer()
          control("forward.end.fill", action: "next", label: nextLabel)
        }
      }
      .padding(14)
    }
    .containerBackground(.clear, for: .widget)
  }

  @ViewBuilder
  private var playbackProgress: some View {
    if entry.player.isPlaying && entry.player.durationMs > 0 {
      ProgressView(timerInterval: entry.player.timerInterval, countsDown: false)
        .tint(Color(red: 1, green: 0.42, blue: 0.37))
    } else {
      ProgressView(value: entry.player.progress)
        .tint(Color(red: 1, green: 0.42, blue: 0.37))
    }
  }

  @ViewBuilder
  private func control(
    _ symbol: String,
    action: String,
    label: String,
    prominent: Bool = false
  ) -> some View {
    Button(intent: ZingChartPlaybackIntent(action: action)) {
      Image(systemName: symbol)
        .frame(width: 30, height: 30)
        .background(prominent ? Color.white : Color.clear, in: Circle())
        .foregroundStyle(prominent ? Color.black : Color.white)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  private var previousLabel: String { localized(vi: "Bài trước", en: "Previous", zh: "上一首") }
  private var playLabel: String { localized(vi: "Phát", en: "Play", zh: "播放") }
  private var pauseLabel: String { localized(vi: "Tạm dừng", en: "Pause", zh: "暂停") }
  private var nextLabel: String { localized(vi: "Bài tiếp", en: "Next", zh: "下一首") }
}

private func localized(vi: String, en: String, zh: String) -> String {
  let language = Locale.current.language.languageCode?.identifier ?? "vi"
  if language == "zh" { return zh }
  if language == "en" { return en }
  return vi
}

@main
struct ZingChartWidgetBundle: WidgetBundle {
  var body: some Widget {
    StaticConfiguration(kind: "ZingChartNowPlaying", provider: PlayerProvider()) {
      PlayerWidgetView(entry: $0)
    }
    .configurationDisplayName("#zingChart")
    .description(localized(
      vi: "Xem và điều khiển bài hát đang phát.",
      en: "See and control the song playing now.",
      zh: "查看并控制当前播放的歌曲。"
    ))
    .supportedFamilies([.systemMedium])
  }
}
