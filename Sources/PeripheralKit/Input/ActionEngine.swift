import CoreGraphics

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
    // Injectable sink allows dispatch to be tested without sending real key events.
    var post: (CGEvent) -> Void = { $0.post(tap: .cgSessionEventTap) }

    func execute(_ actions: [Action]) throws {
        for action in actions {
            let shortcut = action.keyboardShortcut
            guard shortcut.keyCode <= 127,
                  let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else {
                throw MKSleepError.invalidConfiguration("Impossibile creare la scorciatoia.")
            }
            var flags: CGEventFlags = []
            if shortcut.control { flags.insert(.maskControl) }
            if shortcut.option { flags.insert(.maskAlternate) }
            if shortcut.shift { flags.insert(.maskShift) }
            if shortcut.command { flags.insert(.maskCommand) }
            for event in [down, up] {
                event.flags = flags
                event.setIntegerValueField(.eventSourceUserData, value: InputEventEngine.syntheticMarker)
                post(event)
            }
        }
    }
}
