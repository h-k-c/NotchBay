import SwiftUI

final class AISessionModule: IslandModule {
    @ObservedObject private var monitor = AISessionMonitor.shared

    init() {
        super.init(id: "aisession", name: "AI 会话", icon: "brain.head.profile", priority: 50)
    }

    override func compactView() -> AnyView {
        AnyView(AISessionCompact())
    }

    override func expandedView() -> AnyView {
        AnyView(AISessionExpanded())
    }

    override func isRelevant() -> Bool {
        monitor.isThinking || monitor.isExecuting || monitor.isWaitingApproval
    }

    override func startMonitoring() {
        monitor.start()
    }

    override func stopMonitoring() {
        monitor.stop()
    }
}

// MARK: - Compact View

struct AISessionCompact: View {
    @ObservedObject private var monitor = AISessionMonitor.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: monitor.activeAgentIcon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusColor)

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .opacity(pulsing ? 0.4 : 1.0)
                .scaleEffect(pulsing ? 1.3 : 1.0)
                .animation(
                    monitor.isWaitingApproval
                        ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                        : .easeInOut(duration: Constants.pulseDuration).repeatForever(autoreverses: true),
                    value: pulsing
                )

            Text(monitor.statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        
        .onAppear { pulsing = true }
        .onDisappear { pulsing = false }
    }

    @State private var pulsing: Bool = false

    private var statusColor: Color {
        if monitor.isWaitingApproval { return .statusOrange }
        if monitor.isExecuting { return .statusGreen }
        if monitor.isThinking { return .statusPurple }
        return .white.opacity(0.5)
    }
}

// MARK: - Expanded View

struct AISessionExpanded: View {
    @ObservedObject private var monitor = AISessionMonitor.shared
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            if monitor.activeSessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
        }
        .padding(20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("未检测到 AI 会话")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("运行 Claude Code 或 Codex CLI 后自动检测")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 120)
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            let sortedSessions = monitor.activeSessions.values.sorted { $0.lastActiveAt > $1.lastActiveAt }
            ForEach(sortedSessions) { session in
                SessionRow(session: session)
            }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: AISessionMonitor.Session

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: agentIcon)
                .font(.system(size: 14))
                .foregroundStyle(statusColor)
                .frame(width: 28, height: 28)
                .background(statusColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.agent.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)

                Text(statusDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }

            Spacer()

            statusIndicator
        }
        .padding(8)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            // Jump to terminal
            jumpToTerminal()
        }
    }

    private var agentIcon: String {
        switch session.agent {
        case .claude: return "brain.head.profile"
        case .codex: return "terminal"
        case .gemini: return "sparkles"
        case .cursor: return "cursorarrow"
        case .copilot: return "person.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .idle, .completed: return .white.opacity(0.4)
        case .thinking: return .statusPurple
        case .executing: return .statusGreen
        case .waitingApproval: return .statusOrange
        case .error: return .statusRed
        }
    }

    private var statusDescription: String {
        switch session.status {
        case .idle: return "就绪"
        case .thinking: return "思考中..."
        case .executing(let tool): return "执行: \(tool)"
        case .waitingApproval(let prompt): return "等待审批: \(prompt.prefix(40))"
        case .completed: return "已完成"
        case .error(let msg): return "错误: \(msg)"
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch session.status {
        case .thinking:
            ProgressView()
                .scaleEffect(0.6)
                .tint(Color.statusPurple)
        case .executing:
            Image(systemName: "play.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.statusGreen)
        case .waitingApproval:
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.statusOrange)
        default:
            EmptyView()
        }
    }

    private func jumpToTerminal() {
        let script = """
        tell application "System Events"
            set terminalApps to {"Terminal", "iTerm2", "Ghostty", "Warp", "kitty"}
            repeat with appName in terminalApps
                if application appName is running then
                    tell application appName to activate
                    return
                end if
            end repeat
        end tell
        """
        Process.runOsaScriptAsync(script)
    }
}
