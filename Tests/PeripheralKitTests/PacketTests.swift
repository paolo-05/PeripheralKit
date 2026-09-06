import XCTest
#if SWIFT_PACKAGE
@testable import PeripheralKit
#endif

final class PacketTests: XCTestCase {
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
        var state = WorkspacePowerState()
        XCTAssertEqual(state.handle(.screensDidSleep), .sleeping)
        XCTAssertNil(state.handle(.screensDidSleep))
        XCTAssertEqual(state.handle(.screensDidWake), .awake)
    }

    func testSystemWakeDoesNotLightWhileScreensAreStillSleeping() {
        var state = WorkspacePowerState()
        XCTAssertEqual(state.handle(.screensDidSleep), .sleeping)
        XCTAssertNil(state.handle(.systemWillSleep))
        XCTAssertNil(state.handle(.systemDidWake))
        XCTAssertEqual(state.handle(.screensDidWake), .awake)
    }
}
