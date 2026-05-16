import SwiftUI
import AppKit

@main
struct NotchBayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("NotchBay", systemImage: "rectangle.inset.filled.and.cursorarrow") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsWindow()
                .environmentObject(appState)
        }
    }
}

/// Menu bar dropdown content
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var timerState = TimerState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("鼠标移到刘海区域即显示")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            if let module = appState.activeModule {
                Text("Active: \(module.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Image(systemName: "timer")
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text("倒计时")
                        .font(.system(size: 12, weight: .medium))
                    Text(timerState.isRunning ? timerState.formattedRemaining + " 剩余" : "未运行")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if timerState.isRunning {
                    Button("暂停") { timerState.pause() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                } else if timerState.remainingSeconds > 0 {
                    Button("继续") { timerState.resume() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                    Button("重置") { timerState.reset() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Button("5分钟") { timerState.start(seconds: 300) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                    Button("25分钟") { timerState.start(seconds: 1500) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit NotchBay") {
                appState.islandWindow?.terminate()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
