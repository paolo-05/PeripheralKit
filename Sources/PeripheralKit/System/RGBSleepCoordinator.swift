import Foundation

struct RGBStateCache: Sendable {
    private(set) var configuration: Configuration?
    mutating func capture(_ configuration: Configuration) {
        if self.configuration == nil { self.configuration = configuration }
    }
    mutating func clear() { configuration = nil }
}

// Hardware writes are actor-isolated and never run on the main actor.
// Cancellation takes effect between individual HID operations and retries.
actor RGBSleepCoordinator {
    private let adapters: [any RGBDeviceAdapter]
    private let log: @Sendable (String, Bool) -> Void
    private let wait: @Sendable (Double) async throws -> Void
    private let retryDelays: [Double]
    private var cache = RGBStateCache()
    private var pending: Set<String> = []
    private var sleeping = false
    private var generation = 0
    private var restoration: Task<Void, Never>?

    init(adapters: [any RGBDeviceAdapter] = [DrevoRGBAdapter(), RazerRGBAdapter()],
         retryDelays: [Double] = [0, 0.25, 0.5, 1, 2, 4, 8],
         wait: @escaping @Sendable (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) },
         log: @escaping @Sendable (String, Bool) -> Void) {
        self.adapters = adapters
        self.retryDelays = retryDelays
        self.wait = wait
        self.log = log
    }

    func transition(toSleep: Bool, configuration: AppConfiguration) {
        guard toSleep != sleeping else { return }
        sleeping = toSleep
        generation += 1
        restoration?.cancel()
        restoration = nil
        if toSleep {
            cache.capture(configuration.rgb)
            guard let snapshot = cache.configuration else { return }
            for adapter in adapters where adapter.isEnabled(in: snapshot) {
                // Include partial failures: Razer may have switched only one zone off.
                pending.insert(adapter.id)
                do {
                    try adapter.apply(.sleeping, configuration: snapshot)
                    log("RGB spento: \(adapter.name)", false)
                } catch { log("RGB stop: \(error.localizedDescription)", true) }
            }
        } else if configuration.restoreOnWake {
            let current = generation
            let delay = configuration.rgb.wakeDelaySeconds
            restoration = Task { [weak self] in await self?.restore(generation: current, delay: delay) }
        } else {
            cache.clear()
            pending.removeAll()
        }
    }

    private func restore(generation expected: Int, delay: Double) async {
        do {
            try await wait(delay)
            guard isCurrent(expected), let snapshot = cache.configuration else { return }
            let targets = adapters.filter { pending.contains($0.id) }
            await withTaskGroup(of: Void.self) { group in
                for adapter in targets {
                    group.addTask { [weak self] in
                        await self?.restore(adapter, snapshot: snapshot, generation: expected)
                    }
                }
            }
            guard isCurrent(expected) else { return }
            if pending.isEmpty { cache.clear() }
            else { log("Ripristino RGB incompleto: \(pending.sorted().joined(separator: ", ")). Controlla collegamento e permessi.", true) }
        } catch is CancellationError {
            // A newer power state owns subsequent hardware work.
        } catch { log(error.localizedDescription, true) }
    }

    private func isCurrent(_ expected: Int) -> Bool {
        !Task.isCancelled && expected == generation && !sleeping
    }

    private func restore(_ adapter: any RGBDeviceAdapter, snapshot: Configuration, generation expected: Int) async {
        do {
            // Only adapters that need settling get extra writes. The mouse
            // finishes immediately; every apply reconnects to the current HID endpoint.
            for (stage, settleDelay) in ([0] + adapter.wakeReapplyDelays).enumerated() {
                try await wait(settleDelay)
                var sent = false
                for (attempt, retryDelay) in retryDelays.enumerated() {
                    try await wait(retryDelay)
                    guard isCurrent(expected) else { return }
                    do {
                        try adapter.apply(.awake, configuration: snapshot)
                        log("Profilo RGB inviato: \(adapter.name) · passaggio \(stage + 1)", false)
                        sent = true
                        break
                    } catch {
                        log("RGB ripristino \(adapter.name) · tentativo \(attempt + 1)/\(retryDelays.count): \(error.localizedDescription)", true)
                    }
                }
                guard sent else { return }
            }
            guard isCurrent(expected) else { return }
            pending.remove(adapter.id)
            log("Sequenza di ripristino completata: \(adapter.name)", false)
        } catch is CancellationError {
            // Never re-light a device for an obsolete wake generation.
        } catch { log(error.localizedDescription, true) }
    }

    func finishPendingRestoration() async { await restoration?.value }
    func cachedConfiguration() -> Configuration? { cache.configuration }
}
