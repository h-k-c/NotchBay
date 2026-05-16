import SwiftUI
import AppKit
import ServiceManagement

/// Settings window with tabs
struct SettingsWindow: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            ModulesSettings()
                .tabItem {
                    Label("模块", systemImage: "square.grid.2x2")
                }

            AppearanceSettings()
                .tabItem {
                    Label("外观", systemImage: "paintpalette")
                }

            AboutSettings()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettings: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("defaultModuleID") private var defaultModuleID = "nowplaying"
    @AppStorage("autoCollapseTimeout") private var autoCollapseTimeout = 3.0

    var body: some View {
        Form {
            Section {
                Toggle("登录时启动 NotchBay", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin, initial: false) {
                        setLaunchAtLogin(launchAtLogin)
                    }
            }

            Section("默认显示") {
                Picker("默认模块", selection: $defaultModuleID) {
                    Text("正在播放").tag("nowplaying")
                    Text("电池").tag("battery")
                    Text("AI 会话").tag("aisession")
                    Text("天气").tag("weather")
                    Text("日历").tag("calendar")
                }
            }

            Section("交互") {
                Picker("自动折叠", selection: $autoCollapseTimeout) {
                    Text("1 秒后").tag(1.0)
                    Text("3 秒后").tag(3.0)
                    Text("5 秒后").tag(5.0)
                    Text("永不").tag(0.0)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        #if !DEBUG
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logging.error("Launch at login failed: \(error)")
        }
        #endif
    }
}

// MARK: - Modules Settings

struct ModulesSettings: View {
    @State private var modules: [ModuleConfig] = [
        ModuleConfig(id: "nowplaying", name: "正在播放", enabled: true),
        ModuleConfig(id: "battery", name: "电池状态", enabled: true),
        ModuleConfig(id: "aisession", name: "AI 会话", enabled: true),
        ModuleConfig(id: "weather", name: "天气", enabled: true),
        ModuleConfig(id: "calendar", name: "日历", enabled: true),
        ModuleConfig(id: "notification", name: "通知", enabled: true),
    ]

    @State private var batteryLowThreshold: Double = 20
    @State private var calendarAlertMinutes: Double = 5
    @State private var aiSessionPath: String = Constants.claudeProjectPath

    var body: some View {
        Form {
            Section("已安装模块") {
                ForEach($modules) { $module in
                    HStack {
                        Text(module.name)
                        Spacer()
                        Toggle("", isOn: $module.enabled)
                            .toggleStyle(.switch)
                    }
                }
            }

            Section("电池") {
                HStack {
                    Text("低电量阈值")
                    TextField("", value: $batteryLowThreshold, format: .number)
                        .frame(width: 60)
                    Text("%")
                }
            }

            Section("日历") {
                HStack {
                    Text("日程提醒")
                    TextField("", value: $calendarAlertMinutes, format: .number)
                        .frame(width: 60)
                    Text("分钟前")
                }
            }

            Section("AI 会话") {
                HStack {
                    Text("监控目录")
                    TextField("", text: $aiSessionPath)
                        .textFieldStyle(.roundedBorder)
                }

                Button("打开目录") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: aiSessionPath))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    struct ModuleConfig: Identifiable {
        let id: String
        let name: String
        var enabled: Bool
    }
}

// MARK: - Appearance Settings

struct AppearanceSettings: View {
    @AppStorage("compactOpacity") private var compactOpacity = 0.8
    @AppStorage("showModuleDots") private var showModuleDots = true
    @AppStorage("animationSpeed") private var animationSpeed = 1.0

    @AppStorage("notch.width")         private var notchW:       Double = 185
    @AppStorage("notch.capHeight")     private var notchCapH:    Double = 22
    @AppStorage("notch.contentHeight") private var notchContent: Double = 24
    @AppStorage("notch.topRadius")     private var notchTopR:    Double = 0
    @AppStorage("notch.bottomRadius")  private var notchBottomR: Double = 9

    var body: some View {
        Form {
            Section("刘海形状（重启后生效）") {
                LabeledSlider(label: "宽度", value: $notchW, range: 100...350, unit: "pt")
                LabeledSlider(label: "顶部高度（物理遮挡区）", value: $notchCapH, range: 10...40, unit: "pt")
                LabeledSlider(label: "内容区高度", value: $notchContent, range: 10...50, unit: "pt")
                LabeledSlider(label: "顶角凹弧度", value: $notchTopR, range: 0...20, unit: "pt")
                LabeledSlider(label: "底角弧度", value: $notchBottomR, range: 0...20, unit: "pt")

                Button("恢复默认") {
                    notchW = 185; notchCapH = 22; notchContent = 24
                    notchTopR = 0; notchBottomR = 9
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            Section("紧凑模式") {
                HStack {
                    Text("背景不透明度")
                    Slider(value: $compactOpacity, in: 0.3...1.0)
                    Text("\(Int(compactOpacity * 100))%")
                        .frame(width: 36)
                        .font(.system(size: 11, design: .monospaced))
                }
                Toggle("显示模块指示点", isOn: $showModuleDots)
            }

            Section("动画") {
                Picker("动画速度", selection: $animationSpeed) {
                    Text("慢").tag(1.5)
                    Text("标准").tag(1.0)
                    Text("快").tag(0.5)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        HStack {
            Text(label).frame(width: 150, alignment: .leading)
            Slider(value: $value, in: range, step: 1)
            Text("\(Int(value))\(unit)")
                .frame(width: 44)
                .font(.system(size: 11, design: .monospaced))
        }
    }
}

// MARK: - About Settings

struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "rectangle.inset.filled.and.cursorarrow")
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(
                    LinearGradient(
                        colors: [.statusBlue, .statusPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Text("NotchBay")
                .font(.title2.weight(.bold))

            Text("Mac 刘海区域的灵动岛实时状态展示")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Version 1.0.0 (Build 1)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com")!)
                Link("反馈", destination: URL(string: "https://github.com")!)
                Link("隐私政策", destination: URL(string: "https://github.com")!)
            }
            .font(.caption)

            Spacer()
        }
        .padding()
    }
}
