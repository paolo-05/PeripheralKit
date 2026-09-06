import CoreGraphics
import Foundation

@MainActor
protocol ActionExecutor {
    func execute(_ actions: [Action]) throws
}

extension Action {
    var keyboardShortcut: KeyboardShortcut {
        switch self {
        case .previousSpace: KeyboardShortcut(keyCode: 123)
        case .nextSpace: KeyboardShortcut(keyCode: 124)
        case .missionControl: KeyboardShortcut(keyCode: 126)
        case .shortcut(let shortcut): shortcut
        }
    }
}

@MainActor
struct ActionEngine: ActionExecutor {
    // System hotkeys must enter the HID event stream, before session routing.
    // Keep both the event and destination injectable: tests never post input.
    var post: (CGEvent, CGEventTapLocation) -> Void = { $0.post(tap: $1) }
    var canPost: () -> Bool = { CGPreflightPostEventAccess() }

    func execute(_ actions: [Action]) throws {
        guard canPost() else {
            throw ActionDispatchError.accessibilityRequired
        }
        for action in actions {
            let shortcut = action.keyboardShortcut
            guard shortcut.keyCode <= 127,
                  let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else {
                throw PeripheralKitError.invalidConfiguration("Impossibile creare la scorciatoia.")
            }
            var flags: CGEventFlags = []
            if shortcut.control { flags.insert(.maskControl) }
            if shortcut.option { flags.insert(.maskAlternate) }
            if shortcut.shift { flags.insert(.maskShift) }
            if shortcut.command { flags.insert(.maskCommand) }
            for event in [down, up] {
                event.flags = flags
                event.setIntegerValueField(.eventSourceUserData, value: InputEventEngine.syntheticMarker)
                post(event, .cghidEventTap)
            }
        }
    }
}

enum ActionDispatchError: LocalizedError {
    case accessibilityRequired

    var errorDescription: String? {
        "macOS non consente l'invio delle scorciatoie. Autorizza PeripheralKit in Privacy e sicurezza → Accessibilità, poi riapri l'app."
    }
}
