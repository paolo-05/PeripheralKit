import Foundation
import IOKit
import IOKit.hid

struct DrevoPacket: Equatable {
    let bytes: [UInt8]

    init(configuration: KeyboardConfiguration, sleeping: Bool) throws {
        var result = [UInt8](repeating: 0, count: 32)
        let command: UInt8
        switch configuration.mode {
        case .static, .rainbow: command = 0x01
        case .breathing: command = 0x02
        case .stream: command = 0x03
        case .memory: command = 0x0d
        case .radar: command = 0x10
        }

        result[0...6] = [0x06, 0xbe, 0x15, 0x00, 0x01, 0x01, command][...]
        result[7] = Self.scaled(configuration.speed, maximum: 9)
        result[8] = sleeping ? 0 : Self.scaled(configuration.brightness, maximum: 6)
        result[9] = UInt8(clamping: configuration.direction)

        let color = sleeping ? RGBColor(red: 0, green: 0, blue: 0) : try RGBColor(hex: configuration.color)
        let secondary = sleeping ? RGBColor(red: 0, green: 0, blue: 0) : try RGBColor(hex: configuration.secondaryColor)
        result[12...14] = [color.red, color.green, color.blue][...]
        result[15] = (!sleeping && configuration.mode == .rainbow) ? 1 : 0
        result[16...18] = [secondary.red, secondary.green, secondary.blue][...]
        bytes = result
    }

    private static func scaled(_ percentage: Int, maximum: Double) -> UInt8 {
        let clamped = min(max(percentage, 0), 100)
        return UInt8((Double(clamped) / 100.0 * maximum).rounded())
    }
}

final class DrevoTyrfingV2 {
    static let vendorID = 0x0416
    static let productID = 0xa0f8
    private let session = HIDSession()
    private var device: IOHIDDevice?

    func connect() throws {
        let matches = try session.discover(vendorID: Self.vendorID, productID: Self.productID)
        // macOS exposes both Tyrfing interfaces as keyboard usage 0x01:0x06.
        // The RGB endpoint is the only one with a 64-byte output report.
        let candidates = matches.filter { $0.maxOutputReportSize >= 32 }
        guard let descriptor = candidates.max(by: { $0.maxOutputReportSize < $1.maxOutputReportSize }) else {
            throw PeripheralKitError.deviceNotFound("Drevo Tyrfing V2, interfaccia RGB")
        }
        device = try session.open(descriptor, named: "Drevo Tyrfing V2")
    }

    func disconnect() {
        if let device { session.close(device) }
        device = nil
    }

    func apply(_ configuration: KeyboardConfiguration, sleeping: Bool) throws {
        guard let device else { throw PeripheralKitError.deviceNotFound("Drevo Tyrfing V2") }
        var bytes = try DrevoPacket(configuration: configuration, sleeping: sleeping).bytes
        let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0x06, &bytes, bytes.count)
        guard result == kIOReturnSuccess else {
            throw PeripheralKitError.reportFailed("Drevo Tyrfing V2", result)
        }
    }
}
