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
         retryDelays: [Double] = [0, 0.25, 0.5, 1, 2],
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
            for retryDelay in retryDelays {
                try await wait(retryDelay)
                guard !Task.isCancelled, expected == generation, !sleeping, let snapshot = cache.configuration else { return }
                for adapter in adapters where pending.contains(adapter.id) {
                    guard !Task.isCancelled else { return }
                    do {
                        try adapter.apply(.awake, configuration: snapshot)
                        pending.remove(adapter.id)
                        log("RGB ripristinato: \(adapter.name)", false)
                    } catch { log("RGB ripristino: \(error.localizedDescription)", true) }
                }
                if pending.isEmpty { cache.clear(); return }
            }
            log("Ripristino RGB incompleto dopo \(retryDelays.count) tentativi. Controlla collegamento e permessi.", true)
        } catch is CancellationError {
            // A newer power state owns subsequent hardware work.
        } catch { log(error.localizedDescription, true) }
    }

    func finishPendingRestoration() async { await restoration?.value }
    func cachedConfiguration() -> Configuration? { cache.configuration }
}
