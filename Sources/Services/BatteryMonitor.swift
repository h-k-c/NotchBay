import Foundation

// MARK: - Battery Snapshot (via pmset)

private struct BatterySnapshot {
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let timeRemaining: TimeInterval
    let cycleCount: Int
    let health: Int
    let powerWatts: Double
}

private func readBatterySnapshot() -> BatterySnapshot {
    let output = Process.runOsaScript("do shell script \"pmset -g batt; system_profiler SPPowerDataType\"") ?? ""

    var pct = 100
    var charging = false
    var pluggedIn = false
    var timeRemaining: TimeInterval = 0
    var cycleCount = 0
    var health = 100
    var powerWatts = 0.0

    // Parse pmset -g batt output
    // e.g.: " -InternalBattery-0 (id=1234567)  85%; discharging; 2:30 remaining present: true"
    let pmsetLines = output.components(separatedBy: .newlines)
    for line in pmsetLines {
        if line.contains("InternalBattery") {
            if let pctRange = line.range(of: #"\d+%"#, options: .regularExpression) {
                let pctStr = String(line[pctRange]).replacingOccurrences(of: "%", with: "")
                pct = Int(pctStr) ?? 100
            }
            if line.contains("charging") { charging = true }
            if line.contains("discharging") { pluggedIn = false; charging = false }
            if line.contains("AC attached") || line.contains("charged") { pluggedIn = true }
            if let timeRange = line.range(of: #"\d+:\d+"#, options: .regularExpression) {
                let parts = String(line[timeRange]).components(separatedBy: ":")
                if parts.count == 2 {
                    timeRemaining = TimeInterval((Int(parts[0]) ?? 0) * 3600 + (Int(parts[1]) ?? 0) * 60)
                }
            }
        }
    }

    // Parse system_profiler output for cycle count and health
    for line in pmsetLines {
        if line.contains("Cycle Count") {
            cycleCount = Int(line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
        }
        if line.contains("Maximum Capacity") {
            let maxCap = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "") ?? "100"
            health = Int(maxCap) ?? 100
        }
        if line.contains("Wattage") {
            powerWatts = Double(line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "W", with: "") ?? "0") ?? 0
        }
    }

    return BatterySnapshot(
        percentage: pct,
        isCharging: charging,
        isPluggedIn: pluggedIn,
        timeRemaining: timeRemaining,
        cycleCount: cycleCount,
        health: health,
        powerWatts: powerWatts
    )
}

// MARK: - Monitor

@MainActor
final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    @Published var percentage: Int = 100
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var timeRemaining: TimeInterval = 0
    @Published var cycleCount: Int = 0
    @Published var health: Int = 100
    @Published var powerWatts: Double = 0

    private var timer: Timer?

    var isLow: Bool {
        percentage <= Constants.batteryLowThreshold && !isCharging
    }

    private init() {}

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let snapshot = readBatterySnapshot()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.percentage != snapshot.percentage { self.percentage = snapshot.percentage }
                if self.isCharging != snapshot.isCharging { self.isCharging = snapshot.isCharging }
                if self.isPluggedIn != snapshot.isPluggedIn { self.isPluggedIn = snapshot.isPluggedIn }
                if self.timeRemaining != snapshot.timeRemaining { self.timeRemaining = snapshot.timeRemaining }
                if self.cycleCount != snapshot.cycleCount { self.cycleCount = snapshot.cycleCount }
                if self.health != snapshot.health { self.health = snapshot.health }
                if self.powerWatts != snapshot.powerWatts { self.powerWatts = snapshot.powerWatts }
            }
        }
    }
}
