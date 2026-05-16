import Foundation

@MainActor
final class MediaMonitor: ObservableObject {
    static let shared = MediaMonitor()

    @Published var isPlaying: Bool = false
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var duration: TimeInterval = 0
    @Published var elapsed: TimeInterval = 0

    private var timer: Timer?

    private init() {}

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let script = """
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
        end tell
        set playerApps to {"Music", "Spotify", "QQMusic", "NetEaseMusic", "Arc"}
        repeat with appName in playerApps
            try
                if application appName is running then
                    tell application appName
                        if player state is playing then
                            set trackName to name of current track
                            set trackArtist to artist of current track
                            set trackAlbum to album of current track
                            set trackDuration to duration of current track
                            set trackPosition to player position
                            return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration & "|||" & trackPosition & "|||" & appName
                        end if
                    end tell
                end if
            end try
        end repeat
        return ""
        """

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let output = Process.runOsaScript(script) else { return }

            if output.isEmpty {
                DispatchQueue.main.async {
                    guard let self, self.isPlaying else { return }
                    self.isPlaying = false
                    self.title = ""
                    self.artist = ""
                    self.album = ""
                }
                return
            }

            let parts = output.components(separatedBy: "|||")
            guard parts.count >= 6 else { return }

            let newTitle = parts[0]
            let newArtist = parts[1]
            let newAlbum = parts[2]
            let newDuration = TimeInterval(parts[3]) ?? 0
            let newElapsed = TimeInterval(parts[4]) ?? 0

            DispatchQueue.main.async {
                guard let self else { return }
                if self.title != newTitle { self.title = newTitle }
                if self.artist != newArtist { self.artist = newArtist }
                if self.album != newAlbum { self.album = newAlbum }
                self.isPlaying = true  // always set when we got data
                self.duration = newDuration
                self.elapsed = newElapsed
            }
        }
    }

    var displayTitle: String {
        guard isPlaying, !title.isEmpty else { return "" }
        if artist.isEmpty { return title }
        let maxLen = 20
        let combined = "\(title) — \(artist)"
        if combined.count <= maxLen { return combined }
        return "\(String(title.prefix(maxLen - artist.count - 3)))... — \(artist)"
    }
}
