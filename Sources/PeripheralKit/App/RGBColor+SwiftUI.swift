import AppKit
import SwiftUI

extension RGBColor {
    var swiftUIColor: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    init?(swiftUIColor: Color) {
        guard let color = NSColor(swiftUIColor).usingColorSpace(.sRGB) else { return nil }
        self.init(red: UInt8(clamping: Int((color.redComponent * 255).rounded())),
                  green: UInt8(clamping: Int((color.greenComponent * 255).rounded())),
                  blue: UInt8(clamping: Int((color.blueComponent * 255).rounded())))
    }
}

extension Color {
    static func rgb(_ hex: String) -> Color {
        (try? RGBColor(hex: hex))?.swiftUIColor ?? .secondary
    }

    var rgbHex: String? { RGBColor(swiftUIColor: self)?.hex }
}
