import Foundation

protocol LegacyServiceControlling: Sendable {
    func isRunning() throws -> Bool
    func stop() throws
}

struct LaunchctlLegacyService: LegacyServiceControlling {
    private var service: String { "gui/\(getuid())/com.local.mksleep-rgb" }

    func isRunning() throws -> Bool {
        let status = try run(["print", service])
        if status == 0 { return true }
        if status == 113 { return false } // launchctl: service not found.
        throw MigrationError.service("Impossibile verificare MKSleepRGB (launchctl \(status)).")
    }

    func stop() throws {
        let status = try run(["bootout", service])
        guard status == 0 else {
            throw MigrationError.service("Impossibile arrestare MKSleepRGB (launchctl \(status)). Il file originale è stato conservato.")
        }
    }

    private func run(_ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

enum MigrationError: LocalizedError {
    case unexpectedAgent
    case service(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedAgent: "Il LaunchAgent trovato non corrisponde a MKSleepRGB. Nessun servizio è stato modificato."
        case .service(let message): message
        }
    }
}

struct LegacyServiceMigration: Sendable {
    let homeDirectory: URL
    var service: any LegacyServiceControlling = LaunchctlLegacyService()
    var agentURL: URL { homeDirectory.appendingPathComponent("Library/LaunchAgents/com.local.mksleep-rgb.plist") }
    var backupDirectory: URL { homeDirectory.appendingPathComponent("Library/Application Support/PeripheralKit/migration") }

    // Called on a utility task, never while processing a global input event.
    // The user explicitly starts this operation from the installed app.
    func migrate() throws -> URL? {
        let files = FileManager.default
        guard files.fileExists(atPath: agentURL.path) else { return nil }
        let original = try Data(contentsOf: agentURL)
        guard let plist = try PropertyListSerialization.propertyList(from: original, format: nil) as? [String: Any],
              plist["Label"] as? String == "com.local.mksleep-rgb",
              let arguments = plist["ProgramArguments"] as? [String],
              let executable = arguments.first,
              URL(fileURLWithPath: executable).standardizedFileURL == homeDirectory.appendingPathComponent("Applications/MKSleepRGB.app/Contents/MacOS/mksleep-rgb").standardizedFileURL,
              arguments.dropFirst().first == "daemon" else { throw MigrationError.unexpectedAgent }
        try files.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let backup = backupDirectory.appendingPathComponent("com.local.mksleep-rgb-\(UUID().uuidString).plist")
        // Verify the backup before stopping anything. Preserve the source on failure.
        try original.write(to: backup, options: .atomic)
        guard try Data(contentsOf: backup) == original else { throw MigrationError.service("Backup del vecchio servizio non riuscito.") }
        if try service.isRunning() { try service.stop() }
        guard try !service.isRunning() else { throw MigrationError.service("MKSleepRGB risulta ancora attivo. Migrazione interrotta.") }
        // No configuration, certificate, or keychain is deleted or modified.
        try files.removeItem(at: agentURL)
        return backup
    }
}
