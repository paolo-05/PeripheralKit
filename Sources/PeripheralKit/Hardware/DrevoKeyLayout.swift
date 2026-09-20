import Foundation

/// Stable physical identities for the ANSI Tyrfing V2 layout.
/// Firmware report identifiers intentionally live outside this visual model.
enum DrevoKeyID: String, CaseIterable, Codable, Sendable {
    case escape
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
    case printScreen, scrollLock, pause

    case backquote
    case digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9, digit0
    case minus, equal, backspace
    case insert, home, pageUp

    case tab
    case q, w, e, r, t, y, u, i, o, p
    case leftBracket, rightBracket, backslash
    case delete, end, pageDown

    case capsLock
    case a, s, d, f, g, h, j, k, l
    case semicolon, apostrophe, enter

    case leftShift
    case z, x, c, v, b, n, m
    case comma, period, slash, rightShift
    case arrowUp

    case leftControl, leftWindows, leftAlt, space
    case rightAlt, function, menu, rightControl
    case arrowLeft, arrowDown, arrowRight
}

enum DrevoKeyGroup: Sendable {
    case function
    case alphanumeric
    case modifier
    case navigation
    case arrow
}

struct DrevoKeyDescriptor: Equatable, Sendable {
    let id: DrevoKeyID
    let legend: String
    let secondaryLegend: String?
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let group: DrevoKeyGroup

    init(_ id: DrevoKeyID, _ legend: String, secondaryLegend: String? = nil,
         x: Double, y: Double, width: Double = 1, height: Double = 1,
         group: DrevoKeyGroup) {
        self.id = id
        self.legend = legend
        self.secondaryLegend = secondaryLegend
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.group = group
    }
}

enum DrevoTKLLayout {
    static let width = 18.5
    static let height = 6.75

    static let keys: [DrevoKeyDescriptor] = [
        key(.escape, "Esc", x: 0, y: 0, group: .function),
        key(.f1, "F1", x: 2, y: 0, group: .function),
        key(.f2, "F2", x: 3, y: 0, group: .function),
        key(.f3, "F3", x: 4, y: 0, group: .function),
        key(.f4, "F4", x: 5, y: 0, group: .function),
        key(.f5, "F5", x: 6.5, y: 0, group: .function),
        key(.f6, "F6", x: 7.5, y: 0, group: .function),
        key(.f7, "F7", x: 8.5, y: 0, group: .function),
        key(.f8, "F8", x: 9.5, y: 0, group: .function),
        key(.f9, "F9", x: 11, y: 0, group: .function),
        key(.f10, "F10", x: 12, y: 0, group: .function),
        key(.f11, "F11", x: 13, y: 0, group: .function),
        key(.f12, "F12", x: 14, y: 0, group: .function),
        key(.printScreen, "Prt", x: 15.5, y: 0, group: .function),
        key(.scrollLock, "SL", x: 16.5, y: 0, group: .function),
        key(.pause, "Pau", x: 17.5, y: 0, group: .function),

        key(.backquote, "`", secondaryLegend: "~", x: 0, y: 1.75, group: .alphanumeric),
        key(.digit1, "1", secondaryLegend: "!", x: 1, y: 1.75, group: .alphanumeric),
        key(.digit2, "2", secondaryLegend: "@", x: 2, y: 1.75, group: .alphanumeric),
        key(.digit3, "3", secondaryLegend: "#", x: 3, y: 1.75, group: .alphanumeric),
        key(.digit4, "4", secondaryLegend: "$", x: 4, y: 1.75, group: .alphanumeric),
        key(.digit5, "5", secondaryLegend: "%", x: 5, y: 1.75, group: .alphanumeric),
        key(.digit6, "6", secondaryLegend: "^", x: 6, y: 1.75, group: .alphanumeric),
        key(.digit7, "7", secondaryLegend: "&", x: 7, y: 1.75, group: .alphanumeric),
        key(.digit8, "8", secondaryLegend: "*", x: 8, y: 1.75, group: .alphanumeric),
        key(.digit9, "9", secondaryLegend: "(", x: 9, y: 1.75, group: .alphanumeric),
        key(.digit0, "0", secondaryLegend: ")", x: 10, y: 1.75, group: .alphanumeric),
        key(.minus, "-", secondaryLegend: "_", x: 11, y: 1.75, group: .alphanumeric),
        key(.equal, "=", secondaryLegend: "+", x: 12, y: 1.75, group: .alphanumeric),
        key(.backspace, "⌫", x: 13, y: 1.75, width: 2, group: .modifier),
        key(.insert, "Ins", x: 15.5, y: 1.75, group: .navigation),
        key(.home, "Home", x: 16.5, y: 1.75, group: .navigation),
        key(.pageUp, "Pg↑", x: 17.5, y: 1.75, group: .navigation),

        key(.tab, "Tab", x: 0, y: 2.75, width: 1.5, group: .modifier),
        key(.q, "Q", x: 1.5, y: 2.75, group: .alphanumeric),
        key(.w, "W", x: 2.5, y: 2.75, group: .alphanumeric),
        key(.e, "E", x: 3.5, y: 2.75, group: .alphanumeric),
        key(.r, "R", x: 4.5, y: 2.75, group: .alphanumeric),
        key(.t, "T", x: 5.5, y: 2.75, group: .alphanumeric),
        key(.y, "Y", x: 6.5, y: 2.75, group: .alphanumeric),
        key(.u, "U", x: 7.5, y: 2.75, group: .alphanumeric),
        key(.i, "I", x: 8.5, y: 2.75, group: .alphanumeric),
        key(.o, "O", x: 9.5, y: 2.75, group: .alphanumeric),
        key(.p, "P", x: 10.5, y: 2.75, group: .alphanumeric),
        key(.leftBracket, "[", secondaryLegend: "{", x: 11.5, y: 2.75, group: .alphanumeric),
        key(.rightBracket, "]", secondaryLegend: "}", x: 12.5, y: 2.75, group: .alphanumeric),
        key(.backslash, "\\", secondaryLegend: "|", x: 13.5, y: 2.75, width: 1.5, group: .alphanumeric),
        key(.delete, "Del", x: 15.5, y: 2.75, group: .navigation),
        key(.end, "End", x: 16.5, y: 2.75, group: .navigation),
        key(.pageDown, "Pg↓", x: 17.5, y: 2.75, group: .navigation),

        key(.capsLock, "Caps", x: 0, y: 3.75, width: 1.75, group: .modifier),
        key(.a, "A", x: 1.75, y: 3.75, group: .alphanumeric),
        key(.s, "S", x: 2.75, y: 3.75, group: .alphanumeric),
        key(.d, "D", x: 3.75, y: 3.75, group: .alphanumeric),
        key(.f, "F", x: 4.75, y: 3.75, group: .alphanumeric),
        key(.g, "G", x: 5.75, y: 3.75, group: .alphanumeric),
        key(.h, "H", x: 6.75, y: 3.75, group: .alphanumeric),
        key(.j, "J", x: 7.75, y: 3.75, group: .alphanumeric),
        key(.k, "K", x: 8.75, y: 3.75, group: .alphanumeric),
        key(.l, "L", x: 9.75, y: 3.75, group: .alphanumeric),
        key(.semicolon, ";", secondaryLegend: ":", x: 10.75, y: 3.75, group: .alphanumeric),
        key(.apostrophe, "'", secondaryLegend: "\"", x: 11.75, y: 3.75, group: .alphanumeric),
        key(.enter, "↵", x: 12.75, y: 3.75, width: 2.25, group: .modifier),

        key(.leftShift, "Shift", x: 0, y: 4.75, width: 2.25, group: .modifier),
        key(.z, "Z", x: 2.25, y: 4.75, group: .alphanumeric),
        key(.x, "X", x: 3.25, y: 4.75, group: .alphanumeric),
        key(.c, "C", x: 4.25, y: 4.75, group: .alphanumeric),
        key(.v, "V", x: 5.25, y: 4.75, group: .alphanumeric),
        key(.b, "B", x: 6.25, y: 4.75, group: .alphanumeric),
        key(.n, "N", x: 7.25, y: 4.75, group: .alphanumeric),
        key(.m, "M", x: 8.25, y: 4.75, group: .alphanumeric),
        key(.comma, ",", secondaryLegend: "<", x: 9.25, y: 4.75, group: .alphanumeric),
        key(.period, ".", secondaryLegend: ">", x: 10.25, y: 4.75, group: .alphanumeric),
        key(.slash, "/", secondaryLegend: "?", x: 11.25, y: 4.75, group: .alphanumeric),
        key(.rightShift, "Shift", x: 12.25, y: 4.75, width: 2.75, group: .modifier),
        key(.arrowUp, "↑", x: 16.5, y: 4.75, group: .arrow),

        key(.leftControl, "Ctrl", x: 0, y: 5.75, width: 1.25, group: .modifier),
        key(.leftWindows, "Win", x: 1.25, y: 5.75, width: 1.25, group: .modifier),
        key(.leftAlt, "Alt", x: 2.5, y: 5.75, width: 1.25, group: .modifier),
        key(.space, "", x: 3.75, y: 5.75, width: 6.25, group: .modifier),
        key(.rightAlt, "Alt", x: 10, y: 5.75, width: 1.25, group: .modifier),
        key(.function, "Fn", x: 11.25, y: 5.75, width: 1.25, group: .modifier),
        key(.menu, "Menu", x: 12.5, y: 5.75, width: 1.25, group: .modifier),
        key(.rightControl, "Ctrl", x: 13.75, y: 5.75, width: 1.25, group: .modifier),
        key(.arrowLeft, "←", x: 15.5, y: 5.75, group: .arrow),
        key(.arrowDown, "↓", x: 16.5, y: 5.75, group: .arrow),
        key(.arrowRight, "→", x: 17.5, y: 5.75, group: .arrow),
    ]

    static let byID = Dictionary(uniqueKeysWithValues: keys.map { ($0.id, $0) })

    private static func key(_ id: DrevoKeyID, _ legend: String,
                            secondaryLegend: String? = nil,
                            x: Double, y: Double, width: Double = 1,
                            group: DrevoKeyGroup) -> DrevoKeyDescriptor {
        DrevoKeyDescriptor(id, legend, secondaryLegend: secondaryLegend,
                           x: x, y: y, width: width, group: group)
    }
}
