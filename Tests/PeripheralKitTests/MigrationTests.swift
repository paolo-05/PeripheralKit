import XCTest
#if SWIFT_PACKAGE
@testable import PeripheralKit
#endif

private final class MockLegacyService: LegacyServiceControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var running: Bool
    private var stops = 0
    let failStop: Bool
    init(running: Bool = true, failStop: Bool = false) { self.running = running; self.failStop = failStop }
    func isRunning() throws -> Bool { lock.withLock { running } }
    func stop() throws {
        try lock.withLock {
            stops += 1
            if failStop { throw MigrationError.service("Stop fallito") }
            running = false
        }
    }
    var stopCount: Int { lock.withLock { stops } }
}

final class MigrationTests: XCTestCase {
    private func fixture(label: String = "com.local.mksleep-rgb") throws -> (URL, Data) {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let agent = home.appendingPathComponent("Library/LaunchAgents/com.local.mksleep-rgb.plist")
        try FileManager.default.createDirectory(at: agent.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [
            "Label": label,
            "ProgramArguments": [home.appendingPathComponent("Applications/MKSleepRGB.app/Contents/MacOS/mksleep-rgb").path, "daemon"]
        ], format: .xml, options: 0)
        try data.write(to: agent)
        return (home, data)
    }

    func testMigrationStopsOnlyLegacyServiceAndPreservesBackup() throws {
        let (home, original) = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let service = MockLegacyService()
        let migration = LegacyServiceMigration(homeDirectory: home, service: service)
        let backup = try XCTUnwrap(migration.migrate())
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: migration.agentURL.path))
        XCTAssertEqual(service.stopCount, 1)
        XCTAssertNil(try migration.migrate())
    }

    func testStopFailureKeepsOriginalAgent() throws {
        let (home, original) = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let migration = LegacyServiceMigration(homeDirectory: home, service: MockLegacyService(failStop: true))
        XCTAssertThrowsError(try migration.migrate())
        XCTAssertEqual(try Data(contentsOf: migration.agentURL), original)
    }

    func testUnexpectedAgentNeverStopsService() throws {
        let (home, original) = try fixture(label: "another.service")
        defer { try? FileManager.default.removeItem(at: home) }
        let service = MockLegacyService()
        let migration = LegacyServiceMigration(homeDirectory: home, service: service)
        XCTAssertThrowsError(try migration.migrate())
        XCTAssertEqual(service.stopCount, 0)
        XCTAssertEqual(try Data(contentsOf: migration.agentURL), original)
    }

    func testUnloadedAgentStillGetsArchived() throws {
        let (home, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let service = MockLegacyService(running: false)
        let migration = LegacyServiceMigration(homeDirectory: home, service: service)
        XCTAssertNotNil(try migration.migrate())
        XCTAssertEqual(service.stopCount, 0)
    }
}
