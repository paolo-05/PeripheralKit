import Foundation
import OSLog

struct DiagnosticEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let message: String
    let isError: Bool
}

@MainActor
final class Diagnostics: ObservableObject {
    @Published private(set) var entries: [DiagnosticEntry] = []
    private let logger = Logger(subsystem: "com.local.peripheralkit", category: "events")

    func record(_ message: String, error: Bool = false) {
        entries.append(DiagnosticEntry(message: message, isError: error))
        if entries.count > 300 { entries.removeFirst(entries.count - 300) }
        if error { logger.error("\(message, privacy: .public)") }
        else { logger.info("\(message, privacy: .public)") }
    }

    func clear() { entries.removeAll() }
}
