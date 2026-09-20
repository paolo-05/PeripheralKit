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

    func testDrevoModesUseExpectedCommandsAndRainbowFlag() throws {
        let cases: [(KeyboardConfiguration.Mode, UInt8)] = [
            (.static, 0x01), (.rainbow, 0x01), (.breathing, 0x02),
            (.stream, 0x03), (.reactive, 0x0d), (.radar, 0x10),
        ]
        for (mode, command) in cases {
            var configuration = KeyboardConfiguration()
            configuration.mode = mode
            let packet = try DrevoPacket(configuration: configuration, sleeping: false).bytes
            XCTAssertEqual(packet.count, 32, mode.rawValue)
            XCTAssertEqual(packet[6], command, mode.rawValue)
            XCTAssertEqual(packet[15], mode == .rainbow ? 1 : 0, mode.rawValue)
        }
    }

    func testDrevoPacketEncodesColorsSpeedBrightnessAndDirection() throws {
        var configuration = KeyboardConfiguration()
        configuration.mode = .stream
        configuration.color = "#123456"
        configuration.secondaryColor = "#ABCDEF"
        configuration.speed = 50
        configuration.brightness = 50
        configuration.direction = .reverse

        let packet = try DrevoPacket(configuration: configuration, sleeping: false).bytes
        XCTAssertEqual(packet[7], 5)
        XCTAssertEqual(packet[8], 3)
        XCTAssertEqual(packet[9], 1)
        XCTAssertEqual(Array(packet[12...14]), [0x12, 0x34, 0x56])
        XCTAssertEqual(Array(packet[16...18]), [0xab, 0xcd, 0xef])
    }

    func testDrevoPacketClampsPercentagesAtProtocolBoundary() throws {
        var configuration = KeyboardConfiguration()
        configuration.speed = 200
        configuration.brightness = -20
        let packet = try DrevoPacket(configuration: configuration, sleeping: false).bytes
        XCTAssertEqual(packet[7], 9)
        XCTAssertEqual(packet[8], 0)
    }

    func testLegacyMemoryModeAndIntegerDirectionStillDecode() throws {
        let json = ##"{"enabled":true,"mode":"memory","color":"#FFFFFF","secondaryColor":"#FF0000","brightness":80,"speed":60,"direction":1}"##
        let configuration = try JSONDecoder().decode(KeyboardConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(configuration.mode, .reactive)
        XCTAssertEqual(configuration.direction, .reverse)
    }

    func testKeyboardModeCapabilitiesAreTyped() {
        XCTAssertTrue(KeyboardConfiguration.Mode.rainbow.usesAutomaticColors)
        XCTAssertFalse(KeyboardConfiguration.Mode.rainbow.usesPrimaryColor)
        XCTAssertTrue(KeyboardConfiguration.Mode.reactive.usesPrimaryColor)
        XCTAssertTrue(KeyboardConfiguration.Mode.reactive.usesSecondaryColor)
        XCTAssertTrue(KeyboardConfiguration.Mode.stream.supportsDirection)
        XCTAssertTrue(KeyboardConfiguration.Mode.radar.supportsDirection)
        XCTAssertFalse(KeyboardConfiguration.Mode.breathing.supportsDirection)
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
