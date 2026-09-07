import XCTest
#if SWIFT_PACKAGE
@testable import PeripheralKit
#endif

final class PacketTests: XCTestCase {
    func testHappyLightingMatchesWorkingPythonPackets() throws {
        XCTAssertEqual(Array(HappyLightingPacket.power(true)), [204, 35, 51])
        XCTAssertEqual(Array(HappyLightingPacket.power(false)), [204, 36, 51])
        XCTAssertEqual(Array(HappyLightingPacket.color(try RGBColor(hex: "#FF00FF"))), [86, 255, 0, 255, 25, 240, 170])
        XCTAssertEqual(Array(HappyLightingPacket.color(try RGBColor(hex: "#123456"))), [86, 18, 52, 86, 25, 240, 170])
    }

    func testExistingConfigurationWithoutDeskLightStillLoads() throws {
        let encoder = JSONEncoder()
        let original = AppConfiguration()
        let encoded = try encoder.encode(original)
        let restored = try JSONDecoder().decode(AppConfiguration.self, from: encoded)
        XCTAssertNil(restored.deskLight)
        XCTAssertEqual(restored, original)
        var updated = original
        updated.deskLight = DeskLightConfiguration(identifier: UUID(), name: "Triones", color: "#123456")
        XCTAssertEqual(try JSONDecoder().decode(AppConfiguration.self, from: encoder.encode(updated)), updated)
        updated.deskLight?.color = "bad color"
        XCTAssertThrowsError(try updated.validate())
    }

    func testRazerFirmwarePacket() {
        let bytes = RazerReport.firmwareQuery().bytes
        XCTAssertEqual(bytes.count, 90)
        XCTAssertEqual(bytes[1], 0x3f)
        XCTAssertEqual(bytes[5], 0x02)
        XCTAssertEqual(bytes[6], 0x00)
        XCTAssertEqual(bytes[7], 0x81)
        XCTAssertEqual(bytes[88], bytes[2...87].reduce(0, ^))
    }

    func testRazerOffPacketForLogo() {
        let bytes = RazerReport.lighting(.off, zone: .logo).bytes
        XCTAssertEqual(bytes[5], 0x06)
        XCTAssertEqual(bytes[6], 0x0f)
        XCTAssertEqual(bytes[7], 0x02)
        XCTAssertEqual(bytes[8], 0x01)
        XCTAssertEqual(bytes[9], 0x04)
        XCTAssertEqual(bytes[10], 0x00)
    }

    func testDrevoSleepPacketIsDark() throws {
        let packet = try DrevoPacket(configuration: KeyboardConfiguration(), sleeping: true).bytes
        XCTAssertEqual(packet.count, 32)
        XCTAssertEqual(packet[0], 0x06)
        XCTAssertEqual(packet[6], 0x01)
        XCTAssertEqual(packet[8], 0)
        XCTAssertEqual(Array(packet[12...18]), [0, 0, 0, 0, 0, 0, 0])
    }

    func testDrevoDefaultWakePacketUsesRainbowAtFullBrightness() throws {
        let packet = try DrevoPacket(configuration: KeyboardConfiguration(), sleeping: false).bytes
        XCTAssertEqual(packet[8], 6)
        XCTAssertEqual(packet[15], 1)
    }

    func testScreenSleepAndWakeToggleLighting() {
        var policy = SleepPolicy()
        let config = AppConfiguration()
        policy.receive(.displaysDidSleep)
        XCTAssertTrue(policy.shouldSleep(configuration: config))
        policy.receive(.displaysDidSleep)
        XCTAssertTrue(policy.shouldSleep(configuration: config))
        policy.receive(.displaysDidWake)
        XCTAssertFalse(policy.shouldSleep(configuration: config))
    }

    func testSystemWakeDoesNotLightWhileScreensAreStillSleeping() {
        var policy = SleepPolicy()
        let config = AppConfiguration()
        policy.receive(.displaysDidSleep)
        policy.receive(.systemWillSleep)
        policy.receive(.systemDidWake)
        XCTAssertTrue(policy.shouldSleep(configuration: config))
        policy.receive(.displaysDidWake)
        XCTAssertFalse(policy.shouldSleep(configuration: config))
    }
}
