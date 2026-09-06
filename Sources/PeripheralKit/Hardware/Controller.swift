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

struct RGBController {
    let configuration: Configuration

    func apply(_ state: PowerState) -> ApplyResult {
        var result = ApplyResult()

        if configuration.keyboard.enabled {
            let keyboard = DrevoTyrfingV2()
            do {
                try keyboard.connect()
                try keyboard.apply(configuration.keyboard, sleeping: state == .sleeping)
                keyboard.disconnect()
                result.successes.append("Drevo Tyrfing V2")
            } catch {
                keyboard.disconnect()
                result.failures.append(error.localizedDescription)
            }
        }

        if configuration.mouse.enabled {
            let mouse = RazerDeathAdderV2()
            do {
                try mouse.connect()
                let effect: RazerEffect
                if state == .sleeping {
                    effect = .off
                } else {
                    let color = try RGBColor(hex: configuration.mouse.color)
                    switch configuration.mouse.mode {
                    case .spectrum: effect = .spectrum
                    case .static: effect = .static(color)
                    case .breathing: effect = .breathing(color)
                    }
                }
                try mouse.setEffect(effect)
                mouse.disconnect()
                result.successes.append("Razer DeathAdder V2")
            } catch {
                mouse.disconnect()
                result.failures.append(error.localizedDescription)
            }
        }

        return result
    }
}
