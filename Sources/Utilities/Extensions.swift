import SwiftUI
import AppKit
import OSLog

// MARK: - Color Extensions

extension Color {
    static let notchBackground = Color(NSColor.windowBackgroundColor).opacity(0.95)
    static let notchGlass = Color(NSColor.controlBackgroundColor)

    // Status colors
    static let statusGreen = Color(hex: "#22C55E")
    static let statusOrange = Color(hex: "#F97316")
    static let statusRed = Color(hex: "#EF4444")
    static let statusPurple = Color(hex: "#8B5CF6")
    static let statusBlue = Color(hex: "#3B82F6")

    /// Parse hex color with fallback to black
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        let parsed = Scanner(string: hex).scanHexInt64(&int)
        guard parsed, hex.count == 6 || hex.count == 8 else {
            os_log(.error, "Invalid hex color: %{public}@", hex)
            self = .black
            return
        }
        let a, r, g, b: UInt64
        if hex.count == 8 {
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        } else {
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extensions

extension View {
    func notchGlass() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    func islandPill() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: 22))
    }

    /// Standard module row card background
    func moduleCardRow() -> some View {
        self
            .padding(8)
            .background(.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Array Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Process / osascript Helper

extension Process {
    /// Run an osascript command and return its output string, or nil on failure
    @discardableResult
    static func runOsaScript(_ script: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Run an osascript command asynchronously on a background queue
    static func runOsaScriptAsync(_ script: String) {
        DispatchQueue.global(qos: .utility).async {
            runOsaScript(script)
        }
    }
}

// MARK: - TimeInterval Formatting

extension TimeInterval {
    /// "m:ss" format (e.g., "3:45")
    var formattedMinSec: String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Duration in Chinese (e.g., "2小时 30分钟", "5分钟")
    var formattedDuration: String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        if h > 0 { return "\(h)小时 \(m)分钟" }
        return "\(m)分钟"
    }
}

// MARK: - Date Formatting

extension Date {
    /// "HH:mm" formatted time
    var timeString: String {
        Self.timeFormatter.string(from: self)
    }

    /// "EEE" day abbreviation
    var dayString: String {
        Self.dayFormatter.string(from: self)
    }

    /// "HH:mm" for hourly weather
    var hourString: String {
        Self.hourFormatter.string(from: self)
    }

    /// Relative time description: "刚刚", "X分钟前", "HH:mm"
    var relativeDescription: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval/60))分钟前" }
        return timeString
    }

    // Cached formatters (DateFormatter is expensive to create)
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
