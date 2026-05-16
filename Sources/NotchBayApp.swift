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
