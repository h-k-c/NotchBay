import Foundation

@MainActor
final class AISessionMonitor: ObservableObject {
    static let shared = AISessionMonitor()

    @Published var activeSessions: [String: Session] = [:]
    @Published var isThinking: Bool = false
    @Published var isExecuting: Bool = false
    @Published var isWaitingApproval: Bool = false
    @Published var statusText: String = ""
    @Published var activeAgentIcon: String = "brain.head.profile"

    private var pollTimer: Timer?
    private var cleanupTimer: Timer?
    private var previousAggregateState: AggregateState?

    struct Session: Identifiable {
        let id: String
        let name: String
        let workingDirectory: String
        let agent: AgentType
        var status: SessionStatus
        var lastToolCall: String?
        var startedAt: Date
        var lastActiveAt: Date

        enum AgentType: String {
            case claude = "Claude Code"
            case codex = "Codex CLI"
            case gemini = "Gemini CLI"
            case cursor = "Cursor Agent"
            case copilot = "GitHub Copilot"
            case unknown = "AI Agent"
        }

        enum SessionStatus: Equatable {
            case idle
            case thinking
            case executing(tool: String)
            case waitingApproval(prompt: String)
            case completed
            case error(message: String)
        }
    }

    private struct AggregateState: Equatable {
        let isThinking: Bool
        let isExecuting: Bool
        let isWaitingApproval: Bool
        let statusText: String
        let activeAgentIcon: String
    }

    private init() {}

    func start() {
        discoverSessions()
        pollTimer = Timer.scheduledTimer(withTimeInterval: Constants.sessionPollInterval, repeats: true) { [weak self] _ in
            self?.pollSessions()
        }
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.cleanupStaleSessions()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }

    // MARK: - Session Discovery

    private func discoverSessions() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let claude = Self.scanClaudeProjects()
            let codex = Self.scanCodexSessions()
            let all = claude + codex

            DispatchQueue.main.async {
                for session in all {
                    self?.activeSessions[session.id] = session
                }
                self?.updateAggregateState()
            }
        }
    }

    private nonisolated static func scanClaudeProjects() -> [Session] {
        let baseDir = URL(fileURLWithPath: Constants.claudeProjectPath)
        guard let contents = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) else { return [] }

        return contents.compactMap { dir in
            guard dir.hasDirectoryPath else { return nil }
            let sessionFile = dir.appendingPathComponent("session.jsonl")
            guard let modDate = try? FileManager.default.attributesOfItem(atPath: sessionFile.path)[.modificationDate] as? Date else { return nil }
            return Session(
                id: dir.lastPathComponent,
                name: dir.lastPathComponent,
                workingDirectory: dir.path,
                agent: .claude,
                status: .idle,
                startedAt: modDate,
                lastActiveAt: modDate
            )
        }
    }

    private nonisolated static func scanCodexSessions() -> [Session] {
        let codexDir = URL(fileURLWithPath: NSHomeDirectory() + "/.codex/sessions")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: codexDir, includingPropertiesForKeys: nil) else { return [] }

        return contents.compactMap { file in
            guard file.pathExtension == "json", let modDate = try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date else { return nil }
            return Session(
                id: file.deletingPathExtension().lastPathComponent,
                name: "Codex: \(file.deletingPathExtension().lastPathComponent.prefix(12))",
                workingDirectory: NSHomeDirectory(),
                agent: .codex,
                status: .idle,
                startedAt: modDate,
                lastActiveAt: modDate
            )
        }
    }

    // MARK: - Polling (tail-read only)

    private func pollSessions() {
        let sessions = activeSessions
        for (id, session) in sessions {
            let sessionDir: URL
            switch session.agent {
            case .claude:
                sessionDir = URL(fileURLWithPath: Constants.claudeProjectPath).appendingPathComponent(id)
            case .codex:
                sessionDir = URL(fileURLWithPath: NSHomeDirectory() + "/.codex/sessions")
            default:
                continue
            }

            let sessionFile = sessionDir.appendingPathComponent("session.jsonl")
            guard let lastLine = readLastLine(of: sessionFile) else { continue }

            let status = parseStatus(from: lastLine)

            DispatchQueue.main.async { [weak self] in
                guard let self, var existing = self.activeSessions[id] else { return }
                if existing.status != status {
                    existing.status = status
                    existing.lastActiveAt = Date()
                    self.activeSessions[id] = existing
                    self.updateAggregateState()
                }
            }
        }
    }

    private nonisolated func readLastLine(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let chunkSize = 4096
        let fileSize = (try? handle.seekToEnd()) ?? 0
        guard fileSize > 0 else { return nil }

        let searchStart = fileSize > chunkSize ? fileSize - UInt64(chunkSize) : 0
        try? handle.seek(toOffset: searchStart)

        let data = handle.readDataToEndOfFile()
        guard let chunk = String(data: data, encoding: .utf8) else { return nil }
        let lines = chunk.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.last
    }

    private nonisolated func parseStatus(from jsonLine: String) -> Session.SessionStatus {
        guard let jsonData = jsonLine.data(using: .utf8),
              let entry = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return .idle
        }

        let type = entry["type"] as? String ?? ""
        let content = entry["content"] as? String ?? ""
        let tool = entry["tool"] as? String ?? ""

        switch type {
        case "thinking": return .thinking
        case "tool_use": return .executing(tool: tool.isEmpty ? content : tool)
        case "question", "approval_needed": return .waitingApproval(prompt: content)
        case "result", "complete": return .completed
        case "error": return .error(message: content)
        default: return .idle
        }
    }

    // MARK: - Aggregate State (with no-op guards)

    private func updateAggregateState() {
        let allStatuses = activeSessions.values.map { $0.status }

        let thinking = allStatuses.contains { if case .thinking = $0 { return true }; return false }
        let executing = allStatuses.contains { if case .executing = $0 { return true }; return false }
        let waitingApproval = allStatuses.contains { if case .waitingApproval = $0 { return true }; return false }

        let (text, icon): (String, String) = {
            if waitingApproval {
                return ("需要审批", "hand.raised.fill")
            } else if executing {
                var tool = ""
                for s in activeSessions.values {
                    if case .executing(let t) = s.status { tool = t; break }
                }
                return (truncate(text: tool, maxLen: Constants.maxCompactChars), "play.circle.fill")
            } else if thinking {
                return ("思考中...", "brain.head.profile")
            } else {
                return (activeSessions.isEmpty ? "" : "就绪", "brain.head.profile")
            }
        }()

        let newState = AggregateState(
            isThinking: thinking,
            isExecuting: executing,
            isWaitingApproval: waitingApproval,
            statusText: text,
            activeAgentIcon: icon
        )

        guard newState != previousAggregateState else { return }
        previousAggregateState = newState

        isThinking = thinking
        isExecuting = executing
        isWaitingApproval = waitingApproval
        statusText = text
        activeAgentIcon = icon
    }

    // MARK: - Cleanup

    private func cleanupStaleSessions() {
        let cutoff = Date().addingTimeInterval(-1800) // 30 min stale
        let toRemove = activeSessions.filter { $0.value.lastActiveAt < cutoff && !isActive($0.value.status) }
        guard !toRemove.isEmpty else { return }

        for (id, _) in toRemove {
            activeSessions.removeValue(forKey: id)
        }
        if !toRemove.isEmpty {
            updateAggregateState()
        }
    }

    private func isActive(_ status: Session.SessionStatus) -> Bool {
        switch status {
        case .thinking, .executing, .waitingApproval: return true
        default: return false
        }
    }

    private func truncate(text: String, maxLen: Int) -> String {
        text.count <= maxLen ? text : String(text.prefix(maxLen - 3)) + "..."
    }
}
