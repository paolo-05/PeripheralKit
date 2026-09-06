import AppKit
import ApplicationServices

struct InputDecision: Equatable {
    var consume = false
    var capturedButton: Int?
    var rule: Rule?
}

// Pure state machine: a consumed down always consumes its corresponding up,
// even if remapping is switched off while the physical button is held.
struct MouseEventRouter {
    var rules: [Rule] = []
    var enabled = false
    var recording = false
    private var consumedButtons: Set<Int> = []
    private var pressedButtons: Set<Int> = []

    init(rules: [Rule] = [], enabled: Bool = false, recording: Bool = false) {
        self.rules = rules
        self.enabled = enabled
        self.recording = recording
    }

    mutating func route(button: Int, down: Bool, application: String?) -> InputDecision {
        guard (3...32).contains(button) else { return InputDecision() }
        if !down {
            pressedButtons.remove(button)
            return InputDecision(consume: consumedButtons.remove(button) != nil)
        }
        guard pressedButtons.insert(button).inserted else {
            return InputDecision(consume: consumedButtons.contains(button))
        }
        if recording {
            recording = false
            consumedButtons.insert(button)
            return InputDecision(consume: true, capturedButton: button)
        }
        guard enabled, let rule = RuleEngine().match(InputEvent(trigger: .mouseButton(button), applicationBundleID: application), rules: rules) else {
            return InputDecision()
        }
        if rule.consumeOriginalEvent { consumedButtons.insert(button) }
        return InputDecision(consume: rule.consumeOriginalEvent, rule: rule)
    }
}

@MainActor
protocol InputEventSource: AnyObject {
    func start() -> Bool
    func stop()
}

@MainActor
final class InputEventEngine: InputEventSource {
    var router = MouseEventRouter()
    var onButton: ((Int) -> Void)?
    var onCapture: ((Int) -> Void)?
    var onRule: ((Rule) -> Void)?
    var onTapRecovery: (() -> Void)?
    var foregroundApplication: String?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    static let syntheticMarker: Int64 = 0x504B4954

    func start() -> Bool {
        if tap != nil { return true }
        guard AXIsProcessTrusted() else { return false }
        let mask = (CGEventMask(1) << CGEventType.otherMouseDown.rawValue) | (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                // This source is installed exclusively on CFRunLoopGetMain().
                let consume = MainActor.assumeIsolated {
                    Unmanaged<InputEventEngine>.fromOpaque(context).takeUnretainedValue().receive(type, event: event)
                }
                return consume ? nil : Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func receive(_ type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            DispatchQueue.main.async { [weak self] in self?.onTapRecovery?() }
            return false
        }
        guard type == .otherMouseDown || type == .otherMouseUp,
              event.getIntegerValueField(.eventSourceUserData) != Self.syntheticMarker else { return false }
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber)) + 1
        let down = type == .otherMouseDown
        let decision = router.route(button: button, down: down, application: foregroundApplication)
        if down {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onButton?(button)
                if let captured = decision.capturedButton { self.onCapture?(captured) }
                if let rule = decision.rule { self.onRule?(rule) }
            }
        }
        return decision.consume
    }
}
