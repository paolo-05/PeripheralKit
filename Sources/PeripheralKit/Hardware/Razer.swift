import Foundation
import IOKit
import IOKit.hid

enum RazerZone: UInt8, CaseIterable, Sendable {
    case scrollWheel = 0x01
    case logo = 0x04
}

enum RazerEffect: Equatable {
    case off
    case spectrum
    case `static`(RGBColor)
    case breathing(RGBColor)
}

struct RazerReport: Equatable {
    var dataSize: UInt8 = 0
    var commandClass: UInt8 = 0
    var commandID: UInt8 = 0
    var arguments = [UInt8](repeating: 0, count: 80)

    var bytes: [UInt8] {
        var result = [UInt8](repeating: 0, count: 90)
        result[1] = 0x3f
        result[5] = dataSize
        result[6] = commandClass
        result[7] = commandID
        result.replaceSubrange(8..<88, with: arguments)
        result[88] = result[2...87].reduce(0, ^)
        return result
    }

    static func firmwareQuery() -> RazerReport {
        var report = RazerReport()
        report.dataSize = 0x02
        report.commandClass = 0x00
        report.commandID = 0x81
        return report
    }

    static func lighting(_ effect: RazerEffect, zone: RazerZone) -> RazerReport {
        var report = RazerReport()
        report.commandClass = 0x0f
        report.commandID = 0x02
        report.arguments[0] = 0x01
        report.arguments[1] = zone.rawValue

        switch effect {
        case .off:
            report.dataSize = 0x06
            report.arguments[2] = 0x00
        case .static(let color):
            report.dataSize = 0x09
            report.arguments[2] = 0x01
            report.arguments[5] = 0x01
            report.arguments[6...8] = [color.red, color.green, color.blue][...]
        case .breathing(let color):
            report.dataSize = 0x09
            report.arguments[2] = 0x02
            report.arguments[3] = 0x01
            report.arguments[5] = 0x01
            report.arguments[6...8] = [color.red, color.green, color.blue][...]
        case .spectrum:
            report.dataSize = 0x06
            report.arguments[2] = 0x03
        }
        return report
    }
}

final class RazerDeathAdderV2 {
    static let vendorID = 0x1532
    static let productID = 0x0084
    private let session = HIDSession()
    private var device: IOHIDDevice?

    func connect() throws {
        let matches = try session.discover(vendorID: Self.vendorID, productID: Self.productID)
        guard let descriptor = matches.first(where: { $0.maxFeatureReportSize == 90 }) else {
            throw PeripheralKitError.deviceNotFound("Razer DeathAdder V2, interfaccia feature da 90 byte")
        }
        device = try session.open(descriptor, named: "Razer DeathAdder V2")
    }

    func disconnect() {
        if let device { session.close(device) }
        device = nil
    }

    func firmwareVersion() throws -> String {
        guard let device else { throw PeripheralKitError.deviceNotFound("Razer DeathAdder V2") }
        try send(RazerReport.firmwareQuery())
        Thread.sleep(forTimeInterval: 0.3)
        var response = [UInt8](repeating: 0, count: 90)
        var length = CFIndex(response.count)
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0, &response, &length)
        guard result == kIOReturnSuccess, length >= 11 else {
            throw PeripheralKitError.reportFailed("Razer DeathAdder V2 (lettura firmware)", result)
        }
        return "\(response[9]).\(response[10])"
    }

    func setEffect(_ effect: RazerEffect, zone: RazerZone) throws {
        try send(RazerReport.lighting(effect, zone: zone))
        Thread.sleep(forTimeInterval: 0.03)
    }

    func setEffect(_ effect: RazerEffect) throws {
        for zone in RazerZone.allCases {
            try send(RazerReport.lighting(effect, zone: zone))
            Thread.sleep(forTimeInterval: 0.03)
        }
    }

    private func send(_ report: RazerReport) throws {
        guard let device else { throw PeripheralKitError.deviceNotFound("Razer DeathAdder V2") }
        var bytes = report.bytes
        let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0, &bytes, bytes.count)
        guard result == kIOReturnSuccess else {
            throw PeripheralKitError.reportFailed("Razer DeathAdder V2", result)
        }
    }
}
