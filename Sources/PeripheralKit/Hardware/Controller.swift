import Foundation

enum RGBProfileTarget: String, CaseIterable, Sendable {
    case keyboard, mouse

    var adapterID: String {
        switch self {
        case .keyboard: "drevo-0416-a0f8"
        case .mouse: "razer-1532-0084"
        }
    }

    var usbID: (vendor: Int, product: Int) {
        switch self {
        case .keyboard: (0x0416, 0xa0f8)
        case .mouse: (0x1532, 0x0084)
        }
    }

    func matches(_ device: PeripheralDevice) -> Bool {
        device.vendorID == usbID.vendor && device.productID == usbID.product
    }

    static func matching(_ device: PeripheralDevice) -> Self? {
        allCases.first { $0.matches(device) }
    }
}

enum PowerState: String, Sendable {
    case awake
    case sleeping
}

struct ApplyResult: Sendable {
    var successes: [String] = []
    var failures: [String] = []
    var succeeded: Bool { failures.isEmpty }
}

protocol RGBDeviceAdapter: Sendable {
    var id: String { get }
    var name: String { get }
    var wakeReapplyDelays: [Double] { get }
    func isEnabled(in configuration: Configuration) -> Bool
    func apply(_ state: PowerState, configuration: Configuration) throws
    func applyFrame(_ configuration: Configuration, zones: [RazerZone]) throws
}

extension RGBDeviceAdapter {
    var wakeReapplyDelays: [Double] { [] }
    func applyFrame(_ configuration: Configuration, zones: [RazerZone]) throws { try apply(.awake, configuration: configuration) }
}

struct DrevoRGBAdapter: RGBDeviceAdapter {
    let id = RGBProfileTarget.keyboard.adapterID
    let name = "Drevo Tyrfing V2"
    // A USB write can succeed before the keyboard firmware finishes waking.
    // Reopen the endpoint and reapply after it has had time to settle.
    let wakeReapplyDelays: [Double] = [2, 5]
    func isEnabled(in configuration: Configuration) -> Bool { configuration.keyboard.enabled }
    func apply(_ state: PowerState, configuration: Configuration) throws {
        let keyboard = DrevoTyrfingV2()
        defer { keyboard.disconnect() }
        try keyboard.connect()
        try keyboard.apply(configuration.keyboard, sleeping: state == .sleeping)
    }
}

struct RazerRGBAdapter: RGBDeviceAdapter {
    let id = RGBProfileTarget.mouse.adapterID
    let name = "Razer DeathAdder V2"
    func isEnabled(in configuration: Configuration) -> Bool { configuration.mouse.enabled }
    func applyFrame(_ configuration: Configuration, zones: [RazerZone]) throws {
        let mouse = RazerDeathAdderV2()
        defer { mouse.disconnect() }
        try mouse.connect()
        for zone in zones {
            let profile = zone == .logo ? configuration.mouse.logo ?? configuration.mouse.primary : configuration.mouse.primary
            try mouse.setEffect(profile.effect(), zone: zone)
        }
    }
    func apply(_ state: PowerState, configuration: Configuration) throws {
        let mouse = RazerDeathAdderV2()
        defer { mouse.disconnect() }
        try mouse.connect()
        try mouse.setEffect(state == .sleeping ? .off : configuration.mouse.primary.effect(), zone: .scrollWheel)
        try mouse.setEffect(state == .sleeping ? .off : (configuration.mouse.logo ?? configuration.mouse.primary).effect(), zone: .logo)
    }
}

struct RGBController: Sendable {
    let configuration: Configuration
    var adapters: [any RGBDeviceAdapter] = [DrevoRGBAdapter(), RazerRGBAdapter()]

    func apply(_ state: PowerState) -> ApplyResult {
        var result = ApplyResult()
        for adapter in adapters where adapter.isEnabled(in: configuration) {
            do {
                try adapter.apply(state, configuration: configuration)
                result.successes.append(adapter.name)
            } catch { result.failures.append(error.localizedDescription) }
        }
        return result
    }
}
