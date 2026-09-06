import AppKit
import Foundation

// All callbacks are explicitly delivered on OperationQueue.main.
final class SleepWatcher: @unchecked Sendable {
    private let controller: RGBController
    private var observers: [NSObjectProtocol] = []
    private var wakeGeneration = 0
    private var powerState = WorkspacePowerState()

    init(controller: RGBController) {
        self.controller = controller
    }

    func run() -> Never {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handle(.systemWillSleep)
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handle(.systemDidWake)
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handle(.screensDidSleep)
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handle(.screensDidWake)
        })

        Log.info("In ascolto di stop/riattivazione del Mac e degli schermi; accesso HID: \(hidAccessDescription())")
        RunLoop.main.run()
        fatalError("RunLoop terminato inaspettatamente")
    }

    private func handle(_ event: WorkspacePowerEvent) {
        guard let desiredState = powerState.handle(event) else {
            Log.info("Evento \(event.logName): stato RGB invariato")
            return
        }

        wakeGeneration += 1
        guard desiredState == .awake else {
            Log.info("Evento \(event.logName): spengo l'illuminazione")
            log(controller.apply(.sleeping))
            return
        }

        let generation = wakeGeneration
        let delay = max(0, controller.configuration.wakeDelaySeconds)
        Log.info("Evento \(event.logName): ripristino tra \(delay) secondi")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.wakeGeneration == generation else { return }
            self.log(self.controller.apply(.awake))
        }
    }

    private func log(_ result: ApplyResult) {
        for device in result.successes { Log.info("OK: \(device)") }
        for failure in result.failures { Log.error(failure) }
    }
}

enum WorkspacePowerEvent {
    case systemWillSleep
    case systemDidWake
    case screensDidSleep
    case screensDidWake

    var logName: String {
        switch self {
        case .systemWillSleep: return "stop Mac"
        case .systemDidWake: return "risveglio Mac"
        case .screensDidSleep: return "schermi spenti"
        case .screensDidWake: return "schermi riaccesi"
        }
    }
}

struct WorkspacePowerState {
    private(set) var systemSleeping = false
    private(set) var screensSleeping = false

    mutating func handle(_ event: WorkspacePowerEvent) -> PowerState? {
        let wasDark = systemSleeping || screensSleeping
        switch event {
        case .systemWillSleep: systemSleeping = true
        case .systemDidWake: systemSleeping = false
        case .screensDidSleep: screensSleeping = true
        case .screensDidWake: screensSleeping = false
        }

        let isDark = systemSleeping || screensSleeping
        guard wasDark != isDark else { return nil }
        return isDark ? .sleeping : .awake
    }
}

enum Log {
    static func info(_ message: String) {
        print("\(Date().ISO8601Format()) [INFO] \(message)")
        fflush(stdout)
    }

    static func error(_ message: String) {
        let line = "\(Date().ISO8601Format()) [ERRORE] \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
