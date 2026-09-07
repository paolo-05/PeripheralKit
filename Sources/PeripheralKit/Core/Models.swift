import Foundation

struct PeripheralDevice: Identifiable, Equatable, Sendable {
    let id: String
    let vendorID: Int
    let productID: Int
    let serialNumber: String?
    let productName: String
    let manufacturer: String
    let locationID: Int
    let usagePage: Int
    let usage: Int

    var isMouse: Bool { usagePage == 1 && usage == 2 }
    var usbID: String { String(format: "%04x:%04x", vendorID, productID) }
    var supportsRGB: Bool {
        (vendorID == 0x0416 && productID == 0xa0f8) || (vendorID == 0x1532 && productID == 0x0084)
    }
}

struct PeripheralDeviceReference: Codable, Equatable, Sendable {
    var vendorID: Int
    var productID: Int
    var serialNumber: String?
    var locationID: Int?

    func matches(_ device: PeripheralDevice?) -> Bool {
        guard let device, device.vendorID == vendorID, device.productID == productID else { return false }
        if let serialNumber { return device.serialNumber == serialNumber }
        if let locationID { return device.locationID == locationID }
        return true
    }
}

enum SystemEvent: String, Codable, Sendable {
    case systemWillSleep, systemDidWake, displaysDidSleep, displaysDidWake
    case sessionActive, sessionInactive, applicationChanged, spaceChanged
}

enum Trigger: Codable, Equatable, Sendable {
    case mouseButton(Int) // Human numbering: button 4 = Quartz index 3.
    case system(SystemEvent)
}

enum Condition: Codable, Equatable, Sendable {
    case device(PeripheralDeviceReference)
    case application(String)
}

struct KeyboardShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt16 = 123
    var control = true
    var option = false
    var shift = false
    var command = false
}

enum Action: Codable, Equatable, Sendable {
    case previousSpace, nextSpace, missionControl
    case shortcut(KeyboardShortcut)
}

struct Rule: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var enabled = true
    var trigger: Trigger
    var conditions: [Condition] = []
    var actions: [Action]
    var consumeOriginalEvent = true
}

struct InputEvent: Sendable {
    var trigger: Trigger
    var device: PeripheralDevice?
    var applicationBundleID: String?
}

struct RuleEngine {
    func match(_ event: InputEvent, rules: [Rule]) -> Rule? {
        rules.first { rule in
            rule.enabled && rule.trigger == event.trigger && rule.conditions.allSatisfy { condition in
                switch condition {
                case .device(let reference): return reference.matches(event.device)
                case .application(let bundleID): return event.applicationBundleID == bundleID
                }
            }
        }
    }
}

struct AppConfiguration: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var remappingEnabled = false
    var rgbEnabled = true
    var systemSleepEnabled = true
    var displaySleepEnabled = true
    var restoreOnWake = true
    var deskLight: DeskLightConfiguration?
    var rgb = Configuration()
    var rules: [Rule] = [
        Rule(name: "Space precedente", trigger: .mouseButton(4), actions: [.previousSpace]),
        Rule(name: "Space successivo", trigger: .mouseButton(5), actions: [.nextSpace]),
    ]

    func validate() throws {
        guard schemaVersion == 1 else { throw PeripheralKitError.invalidConfiguration("Versione configurazione non supportata: \(schemaVersion)") }
        guard rgb.wakeDelaySeconds.isFinite, (0...30).contains(rgb.wakeDelaySeconds) else {
            throw PeripheralKitError.invalidConfiguration("Il ritardo di risveglio deve essere tra 0 e 30 secondi.")
        }
        if let deskLight { _ = try RGBColor(hex: deskLight.color) }
        _ = try RGBColor(hex: rgb.keyboard.color)
        _ = try RGBColor(hex: rgb.keyboard.secondaryColor)
        _ = try RGBColor(hex: rgb.mouse.color)
        guard Set(rules.map(\.id)).count == rules.count, rules.count <= 256 else {
            throw PeripheralKitError.invalidConfiguration("Regole duplicate o troppe regole (massimo 256).")
        }
        for rule in rules {
            if case .mouseButton(let button) = rule.trigger, !(3...32).contains(button) {
                throw PeripheralKitError.invalidConfiguration("Sono ammessi solo pulsanti aggiuntivi da 3 a 32.")
            }
            for action in rule.actions {
                if case .shortcut(let shortcut) = action, shortcut.keyCode > 127 {
                    throw PeripheralKitError.invalidConfiguration("Codice tasto non valido (0–127).")
                }
            }
        }
    }
}

// Cocoa and Xcode may prepend launch arguments such as
// -NSDocumentRevisionsDebugMode YES. Only explicit CLI verbs select the CLI.
enum LaunchMode: Equatable {
    case application, commandLine

    static func resolve(arguments: [String]) -> LaunchMode {
        let commands = ["help", "--help", "-h", "devices", "check", "authorize", "off", "on", "test", "unregister-login"]
        return arguments.first.map { commands.contains($0) } == true ? .commandLine : .application
    }
}

struct DeskLightConfiguration: Codable, Equatable, Sendable {
    var identifier: UUID
    var name: String
    var color = "#FF00FF"
}
