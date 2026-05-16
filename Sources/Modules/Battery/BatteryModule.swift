import SwiftUI

final class BatteryModule: IslandModule {
    @ObservedObject private var monitor = BatteryMonitor.shared

    init() {
        super.init(id: "battery", name: "电池", icon: "battery.100percent", priority: 60)
    }

    override func compactView() -> AnyView {
        AnyView(BatteryCompact())
    }

    override func expandedView() -> AnyView {
        AnyView(BatteryExpanded())
    }

    override func isRelevant() -> Bool {
        monitor.isLow
    }

    override func startMonitoring() {
        monitor.start()
    }

    override func stopMonitoring() {
        monitor.stop()
    }
}

// MARK: - Compact View

struct BatteryCompact: View {
    @ObservedObject private var monitor = BatteryMonitor.shared

    var body: some View {
        NotchActivityView(
            label: monitor.isCharging ? "充电中" : "电池",
            value: "\(monitor.percentage)%",
            rightBar: .init(fraction: Double(monitor.percentage) / 100.0, color: barColor)
        )
    }

    private var barColor: Color {
        if monitor.isCharging { return .statusGreen }
        if monitor.percentage <= 20 { return .statusRed }
        return .white.opacity(0.7)
    }
}

// MARK: - Expanded View

struct BatteryExpanded: View {
    @ObservedObject private var monitor = BatteryMonitor.shared

    var body: some View {
        VStack(spacing: 20) {
            // Battery visualization
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(monitor.percentage) / 100)
                    .stroke(batteryGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: monitor.percentage)

                VStack(spacing: 0) {
                    Text("\(monitor.percentage)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("%")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            VStack(spacing: 8) {
                DetailRow(label: "状态", value: monitor.isCharging ? "充电中" : (monitor.isPluggedIn ? "已充满" : "使用中"))
                DetailRow(label: "电池健康", value: "\(monitor.health)%")
                DetailRow(label: "循环次数", value: "\(monitor.cycleCount)")
                DetailRow(label: "功率", value: String(format: "%.1fW", abs(monitor.powerWatts)))

                if !monitor.isCharging && monitor.timeRemaining > 0 {
                    DetailRow(label: "剩余时间", value: monitor.timeRemaining.formattedDuration)
                }
            }
        }
        .padding(20)
    }

    private var batteryGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: monitor.isLow
                ? [.statusRed, .statusOrange]
                : [.statusGreen, .green.opacity(0.7)]),
            center: .center
        )
    }

}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
