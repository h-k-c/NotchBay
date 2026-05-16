import Foundation

/// App-wide constants
enum Constants {

    // MARK: - Window

    static let compactHeight: CGFloat = 36
    static let compactWidth: CGFloat = 460  // Wider to wrap around notch (left + gap + right)
    static let expandedHeight: CGFloat = 280
    static let expandedWidth: CGFloat = 340
    static let cornerRadius: CGFloat = 22

    // MARK: - Animation

    static let expandSpring = (response: 0.5, dampingFraction: 0.7)
    static let collapseDuration: CGFloat = 0.25
    static let sceneSwitchDuration: CGFloat = 0.2
    static let pulseDuration: CGFloat = 1.5
    static let hoverDuration: CGFloat = 0.15

    // MARK: - Scene Detection

    static let sceneDebounceInterval: TimeInterval = 0.5
    static let batteryLowThreshold: Int = 20

    // MARK: - Modules

    static let maxCompactChars: Int = 28

    // MARK: - AI Session

    static let claudeProjectPath = NSHomeDirectory() + "/.claude/projects"
    static let sessionPollInterval: TimeInterval = 0.5

    // MARK: - Weather

    static let weatherUpdateInterval: TimeInterval = 900 // 15 min
}
