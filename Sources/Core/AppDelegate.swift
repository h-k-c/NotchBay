import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        try? "launched".write(to: URL(fileURLWithPath: "/tmp/notchbay_launched"), atomically: true, encoding: .utf8)

        NSApp.setActivationPolicy(.accessory)

        MainActor.assumeIsolated {
            let islandWindow = IslandWindow()
            islandWindow.show()

            let state = AppState.shared
            state.registerModule(NowPlayingModule())
            state.registerModule(BatteryModule())
            state.registerModule(AISessionModule())
            state.registerModule(WeatherModule())
            state.registerModule(CalendarModule())
            state.registerModule(NotificationModule())
            state.registerModule(ClipboardModule())
            state.registerModule(TimerModule())
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppState.shared.islandWindow?.terminate()
        }
    }
}
