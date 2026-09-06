import AppKit

@MainActor
protocol SystemEventSource: AnyObject {
    func start()
    func stop()
}

@MainActor
final class SystemEventMonitor: SystemEventSource {
    var onEvent: ((SystemEvent) -> Void)?
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        let pairs: [(Notification.Name, SystemEvent)] = [
            (NSWorkspace.willSleepNotification, .systemWillSleep),
            (NSWorkspace.didWakeNotification, .systemDidWake),
            (NSWorkspace.screensDidSleepNotification, .displaysDidSleep),
            (NSWorkspace.screensDidWakeNotification, .displaysDidWake),
            (NSWorkspace.sessionDidBecomeActiveNotification, .sessionActive),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionInactive),
            (NSWorkspace.didActivateApplicationNotification, .applicationChanged),
            (NSWorkspace.activeSpaceDidChangeNotification, .spaceChanged),
        ]
        for (name, event) in pairs {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onEvent?(event) }
            })
        }
    }

    func stop() {
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }
}

struct SleepPolicy {
    var systemSleeping = false
    var displaysSleeping = false

    mutating func receive(_ event: SystemEvent) {
        switch event {
        case .systemWillSleep: systemSleeping = true
        case .systemDidWake: systemSleeping = false
        case .displaysDidSleep: displaysSleeping = true
        case .displaysDidWake: displaysSleeping = false
        default: break
        }
    }

    func shouldSleep(configuration: AppConfiguration) -> Bool {
        configuration.rgbEnabled && ((configuration.systemSleepEnabled && systemSleeping) || (configuration.displaySleepEnabled && displaysSleeping))
    }
}
