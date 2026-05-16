import Foundation
import OSLog

/// Centralized logging with cached OSLog instances
enum Logging {
    private static let subsystem = "com.notchbay.app"

    private static let aiLog = OSLog(subsystem: subsystem, category: "ai")
    private static let weatherLog = OSLog(subsystem: subsystem, category: "weather")
    private static let generalLog = OSLog(subsystem: subsystem, category: "general")
    private static let errorLog = OSLog(subsystem: subsystem, category: "error")

    static func ai(_ message: String) {
        os_log(.debug, log: aiLog, "\(message)")
    }

    static func weather(_ message: String) {
        os_log(.debug, log: weatherLog, "\(message)")
    }

    static func general(_ message: String) {
        os_log(.info, log: generalLog, "\(message)")
    }

    static func error(_ message: String) {
        os_log(.error, log: errorLog, "\(message)")
    }
}
