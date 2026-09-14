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
    var spectrumColors: [String]?
    var spectrumDurationSeconds: Double?

    var logo: MouseZoneConfiguration?
    var customSpectrum: Bool { mode == .spectrum && spectrumColors != nil || logo?.customSpectrum == true }
    var primary: MouseZoneConfiguration {
        get { MouseZoneConfiguration(mode: mode, color: color, spectrumColors: spectrumColors, spectrumDurationSeconds: spectrumDurationSeconds) }
        set { mode = newValue.mode; color = newValue.color; spectrumColors = newValue.spectrumColors; spectrumDurationSeconds = newValue.spectrumDurationSeconds }
    }
}

struct MouseZoneConfiguration: Codable, Equatable, Sendable {
    var mode = MouseConfiguration.Mode.spectrum
    var color = "#00FF00"
    var spectrumColors: [String]?
    var spectrumDurationSeconds: Double?
    var customSpectrum: Bool { mode == .spectrum && spectrumColors != nil }

    func effect(at seconds: Double = 0) throws -> RazerEffect {
        switch mode {
        case .static: return .static(try RGBColor(hex: color))
        case .breathing: return .breathing(try RGBColor(hex: color))
        case .spectrum:
            if let spectrumColors {
                return .static(try RGBGradient(colors: spectrumColors, duration: spectrumDurationSeconds ?? 12).color(at: seconds))
            }
            return .spectrum
        }
    }
}

struct RGBGradient: Sendable {
    let colors: [RGBColor]
    let duration: Double

    init(colors: [String], duration: Double) throws {
        guard (2...8).contains(colors.count), duration.isFinite, (2...120).contains(duration) else {
            throw PeripheralKitError.invalidConfiguration("Il gradiente richiede da 2 a 8 colori e un ciclo da 2 a 120 secondi.")
        }
        self.colors = try colors.map { try RGBColor(hex: $0) }
        self.duration = duration
    }

    func color(at elapsed: Double) -> RGBColor {
        guard elapsed.isFinite else { return colors[0] }
        let phase = max(0, elapsed.truncatingRemainder(dividingBy: duration)) / duration * Double(colors.count)
        let index = min(Int(phase), colors.count - 1)
        let amount = phase - Double(index)
        let start = colors[index], end = colors[(index + 1) % colors.count]
        func blend(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(clamping: Int((Double(a) + (Double(b) - Double(a)) * amount).rounded()))
        }
        return RGBColor(red: blend(start.red, end.red), green: blend(start.green, end.green), blue: blend(start.blue, end.blue))
    }
}

struct RGBColor: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red; self.green = green; self.blue = blue
    }

    var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }

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
