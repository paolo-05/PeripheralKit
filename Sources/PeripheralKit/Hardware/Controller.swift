import Foundation

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
    func isEnabled(in configuration: Configuration) -> Bool
    func apply(_ state: PowerState, configuration: Configuration) throws
}

struct DrevoRGBAdapter: RGBDeviceAdapter {
    let id = "drevo-0416-a0f8"
    let name = "Drevo Tyrfing V2"
    func isEnabled(in configuration: Configuration) -> Bool { configuration.keyboard.enabled }
    func apply(_ state: PowerState, configuration: Configuration) throws {
        let keyboard = DrevoTyrfingV2()
        defer { keyboard.disconnect() }
        try keyboard.connect()
        try keyboard.apply(configuration.keyboard, sleeping: state == .sleeping)
    }
}

struct RazerRGBAdapter: RGBDeviceAdapter {
    let id = "razer-1532-0084"
    let name = "Razer DeathAdder V2"
    func isEnabled(in configuration: Configuration) -> Bool { configuration.mouse.enabled }
    func apply(_ state: PowerState, configuration: Configuration) throws {
        let mouse = RazerDeathAdderV2()
        defer { mouse.disconnect() }
        try mouse.connect()
        let effect: RazerEffect
        if state == .sleeping { effect = .off }
        else {
            let color = try RGBColor(hex: configuration.mouse.color)
            switch configuration.mouse.mode {
            case .spectrum: effect = .spectrum
            case .static: effect = .static(color)
            case .breathing: effect = .breathing(color)
            }
        }
        try mouse.setEffect(effect)
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
