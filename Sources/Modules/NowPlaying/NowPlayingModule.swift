import SwiftUI

final class NowPlayingModule: IslandModule {
    @ObservedObject private var monitor = MediaMonitor.shared

    init() {
        super.init(id: "nowplaying", name: "正在播放", icon: "music.note", priority: 30)
    }

    override func compactView() -> AnyView {
        AnyView(NowPlayingCompact())
    }

    override func expandedView() -> AnyView {
        AnyView(NowPlayingExpanded())
    }

    override func isRelevant() -> Bool {
        monitor.isPlaying
    }

    override func startMonitoring() {
        monitor.start()
    }

    override func stopMonitoring() {
        monitor.stop()
    }
}

// MARK: - Compact View

struct NowPlayingCompact: View {
    @ObservedObject private var monitor = MediaMonitor.shared

    var body: some View {
        NotchActivityView(
            left: AnyView(EqualizerBars().opacity(monitor.isPlaying ? 1 : 0.3)),
            label: monitor.artist.isEmpty ? "音乐" : monitor.artist,
            value: {
                let t = monitor.title.isEmpty ? "未在播放" : monitor.title
                return t.count > 22 ? String(t.prefix(22)) : t
            }()
        )
    }
}

// MARK: - Expanded View

struct NowPlayingExpanded: View {
    @ObservedObject private var monitor = MediaMonitor.shared

    var body: some View {
        VStack(spacing: 16) {
            if !monitor.isPlaying || monitor.title.isEmpty {
                emptyState
            } else {
                playingContent
            }
        }
        .padding(20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("未检测到播放中的音乐")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("打开 Music 或 Spotify 开始播放")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 120)
    }

    private var playingContent: some View {
        VStack(spacing: 16) {
            // Artwork or icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "music.note")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack(spacing: 4) {
                Text(monitor.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(monitor.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white)
                            .frame(width: monitor.duration > 0
                                ? geo.size.width * (monitor.elapsed / monitor.duration)
                                : 0,
                                height: 4)
                            .animation(.linear(duration: 0.5), value: monitor.elapsed)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(monitor.elapsed.formattedMinSec)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(monitor.duration.formattedMinSec)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Controls
            HStack(spacing: 24) {
                Button(action: { sendMediaCommand("previous track") }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: { sendMediaCommand("playpause") }) {
                    Image(systemName: monitor.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: { sendMediaCommand("next track") }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sendMediaCommand(_ command: String) {
        let script = "tell application \"System Events\" to tell process \"Music\" to \(command)"
        Process.runOsaScriptAsync(script)
    }
}
