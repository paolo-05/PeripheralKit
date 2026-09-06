import Foundation

struct Configuration: Codable, Equatable, Sendable {
    var keyboard = KeyboardConfiguration()
    var mouse = MouseConfiguration()
    var wakeDelaySeconds = 1.0

    static func load(from path: String?) throws -> Configuration {
        guard let path else { return Configuration() }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(Configuration.self, from: data)
    }
}

struct KeyboardConfiguration: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable, Sendable {
        case `static`
        case rainbow
        case breathing
        case stream
        case radar
        case memory
    }

    var enabled = true
    var mode = Mode.rainbow
    var color = "#FFFFFF"
    var secondaryColor = "#FF0000"
    var brightness = 100
    var speed = 100
    var direction = 0
}

struct MouseConfiguration: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable, Sendable {
        case spectrum
        case `static`
        case breathing
    }

    var enabled = true
    var mode = Mode.spectrum
    var color = "#00FF00"
}

struct RGBColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    init(hex: String) throws {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else {
            throw PeripheralKitError.invalidConfiguration("Colore non valido: \(hex). Usa il formato #RRGGBB.")
        }
        red = UInt8((number >> 16) & 0xff)
        green = UInt8((number >> 8) & 0xff)
        blue = UInt8(number & 0xff)
    }
}
