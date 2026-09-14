import Foundation

/// Main-actor orchestration matches CoreBluetooth's delegate queue. Every new
/// intent invalidates callbacks and delayed retries before cancelling transport.
@MainActor
final class DeskLightSleepCoordinator {
    private let transport: any DeskLightTransport
    private let log: (String, Bool) -> Void
    private let wait: (Double) async throws -> Void
    private var generation = 0
    private var task: Task<Void, Never>?
    private var sleeping = false
    private var selectedID: UUID?
    private var enabled = false
    private var restoreAllowed = true
    private var snapshot: DeskLightConfiguration?

    init(transport: any DeskLightTransport,
         wait: @escaping (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) },
         log: @escaping (String, Bool) -> Void) {
        self.transport = transport
        self.wait = wait
        self.log = log
    }

    func update(configuration: AppConfiguration, policy: SleepPolicy) {
        let light = configuration.deskLight
        let active = light?.sleepEnabled == true
        if restoreAllowed && !configuration.restoreOnWake && !sleeping {
            invalidate()
            snapshot = nil
        }
        restoreAllowed = configuration.restoreOnWake
        if selectedID != light?.identifier || enabled != active {
            invalidate()
            snapshot = nil
            selectedID = light?.identifier
            enabled = active
            sleeping = false
        }
        let shouldSleep = active && ((configuration.systemSleepEnabled && policy.systemSleeping)
            || (configuration.displaySleepEnabled && policy.displaysSleeping))
        guard sleeping != shouldSleep else { return }
        sleeping = shouldSleep
        invalidate()
        if shouldSleep {
            guard let light, light.requestedOn == true else { return }
            if snapshot == nil { snapshot = light }
            issue(light, on: false, delay: 0, attempts: 1)
        } else {
            guard configuration.restoreOnWake, light?.requestedOn == true, let saved = snapshot else {
                snapshot = nil
                return
            }
            issue(saved, on: true, delay: max(1, configuration.rgb.wakeDelaySeconds), attempts: 3)
        }
    }

    func manual(_ light: DeskLightConfiguration, on: Bool) {
        invalidate()
        snapshot = nil
        issue(light, on: on, delay: 0, attempts: 1)
    }

    func cancel() {
        invalidate()
        snapshot = nil
    }

    private func invalidate() {
        generation += 1
        task?.cancel()
        task = nil
        transport.cancel()
    }

    private func issue(_ light: DeskLightConfiguration, on: Bool, delay: Double, attempts: Int) {
        let expected = generation
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.wait(delay)
                guard !Task.isCancelled, self.generation == expected else { return }
                let color = try RGBColor(hex: light.requestedColor ?? light.color)
                self.transport.send(to: light.identifier, on: on, color: color) { [weak self] result in
                    guard let self, self.generation == expected else { return }
                    switch result {
                    case .success:
                        if on { self.snapshot = nil }
                        self.log("Luci scrivania: comando \(on ? "accensione e colore" : "spegnimento") confermato dal controller", false)
                    case .failure(let error):
                        guard !(error is CancellationError) else { return }
                        self.log("Luci scrivania: \(error.localizedDescription)", true)
                        if attempts > 1 {
                            self.log("Luci scrivania: nuovo tentativo fra 2 secondi (\(attempts - 1) rimanenti)", false)
                            self.issue(light, on: on, delay: 2, attempts: attempts - 1)
                        }
                    }
                }
            } catch is CancellationError {
                // A newer power event or manual command owns the device.
            } catch { self.log("Luci scrivania: \(error.localizedDescription)", true) }
        }
    }

    func finishScheduledCommand() async { await task?.value }
}

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
    private var mouseCycle: Task<Void, Never>?
    private var cycleGeneration = 0
    private let cycleWait: @Sendable (Double) async throws -> Void

    init(adapters: [any RGBDeviceAdapter] = [DrevoRGBAdapter(), RazerRGBAdapter()],
         retryDelays: [Double] = [0, 0.25, 0.5, 1, 2, 4, 8],
         wait: @escaping @Sendable (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) },
         cycleWait: @escaping @Sendable (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) },
         log: @escaping @Sendable (String, Bool) -> Void) {
        self.adapters = adapters
        self.retryDelays = retryDelays
        self.wait = wait
        self.cycleWait = cycleWait
        self.log = log
    }

    func transition(toSleep: Bool, configuration: AppConfiguration) {
        guard toSleep != sleeping else { return }
        sleeping = toSleep
        generation += 1
        restoration?.cancel()
        restoration = nil
        if toSleep {
            if configuration.rgb.mouse.enabled { stopMouseCycle() }
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

    /// Replace selected-device wake work and retain the other device's snapshot.
    /// A delayed firmware reapply must never overwrite a newer manual profile.
    func applyProfile(_ configuration: Configuration, target: RGBProfileTarget? = nil) -> ApplyResult {
        guard !sleeping else {
            return ApplyResult(failures: ["RGB in stop: riattiva gli schermi prima di applicare il profilo."])
        }
        let selected = adapters.filter { adapter in
            if let target { return adapter.id == target.adapterID }
            return adapter.isEnabled(in: configuration)
        }
        guard !selected.isEmpty else { return ApplyResult() }
        if selected.contains(where: { $0.id == RGBProfileTarget.mouse.adapterID }) { stopMouseCycle() }
        generation += 1
        restoration?.cancel()
        restoration = nil
        let previous = cache.configuration
        pending.subtract(selected.map(\.id))
        cache.clear()
        if target == nil { pending.removeAll() }
        else if var remaining = previous, !pending.isEmpty {
            if target == .keyboard { remaining.keyboard = configuration.keyboard }
            else { remaining.mouse = configuration.mouse }
            cache.capture(remaining)
        }
        var commandConfiguration = configuration
        if target == .keyboard { commandConfiguration.keyboard.enabled = true }
        if target == .mouse { commandConfiguration.mouse.enabled = true }
        let result = RGBController(configuration: commandConfiguration, adapters: selected).apply(.awake)
        for name in result.successes { log("Profilo RGB manuale inviato: \(name)", false) }
        for failure in result.failures { log("Profilo RGB manuale: \(failure)", true) }
        if let mouse = selected.first(where: { $0.id == RGBProfileTarget.mouse.adapterID }), result.successes.contains(mouse.name) {
            startMouseCycle(configuration, adapter: mouse)
        }
        if !pending.isEmpty, cache.configuration != nil {
            let current = generation
            restoration = Task { [weak self] in await self?.restore(generation: current, delay: 0) }
        }
        return result
    }

    func reconnect(_ targets: Set<String>, configuration: Configuration) {
        guard !sleeping, !targets.isEmpty else { return }
        generation += 1
        restoration?.cancel()
        pending.formUnion(targets)
        cache.clear()
        cache.capture(configuration)
        if targets.contains(RGBProfileTarget.mouse.adapterID) { stopMouseCycle() }
        let expected = generation
        restoration = Task { [weak self] in await self?.restore(generation: expected, delay: 0.5) }
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
            if adapter.id == RGBProfileTarget.mouse.adapterID { startMouseCycle(snapshot, adapter: adapter) }
            log("Sequenza di ripristino completata: \(adapter.name)", false)
        } catch is CancellationError {
            // Never re-light a device for an obsolete wake generation.
        } catch { log(error.localizedDescription, true) }
    }

    func finishPendingRestoration() async { await restoration?.value }
    func cachedConfiguration() -> Configuration? { cache.configuration }

    func resumeSavedMouseCycle(_ configuration: Configuration) {
        guard !sleeping, configuration.mouse.customSpectrum,
              let adapter = adapters.first(where: { $0.id == RGBProfileTarget.mouse.adapterID }) else { return }
        startMouseCycle(configuration, adapter: adapter)
    }

    func finishCurrentMouseCycle() async { await mouseCycle?.value }

    func stopMouseCycle() {
        cycleGeneration += 1
        mouseCycle?.cancel()
        mouseCycle = nil
    }

    func shutdown() {
        generation += 1
        restoration?.cancel()
        stopMouseCycle()
    }

    private func startMouseCycle(_ configuration: Configuration, adapter: any RGBDeviceAdapter) {
        stopMouseCycle()
        guard configuration.mouse.customSpectrum else { return }
        let expected = cycleGeneration
        log("Gradiente mouse avviato", false)
        mouseCycle = Task { [weak self] in
            await self?.runMouseCycle(configuration: configuration, adapter: adapter, generation: expected)
        }
    }

    private func runMouseCycle(configuration: Configuration,
                               adapter: any RGBDeviceAdapter, generation expected: Int) async {
        let clock = ContinuousClock()
        let started = clock.now
        var failures = 0
        do {
            while !Task.isCancelled && cycleGeneration == expected {
                try await cycleWait(failures == 0 ? 0.1 : Double(failures))
                guard !Task.isCancelled, cycleGeneration == expected else { return }
                let elapsed = started.duration(to: clock.now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                var frame = configuration
                if configuration.mouse.primary.customSpectrum,
                   case .static(let color) = try configuration.mouse.primary.effect(at: seconds) {
                    frame.mouse.mode = .static
                    frame.mouse.color = color.hex
                }
                if let logo = configuration.mouse.logo, logo.customSpectrum,
                   case .static(let color) = try logo.effect(at: seconds) {
                    frame.mouse.logo?.mode = .static
                    frame.mouse.logo?.color = color.hex
                }
                do {
                    let zones: [RazerZone] = RazerZone.allCases.filter {
                        ($0 == .logo ? configuration.mouse.logo ?? configuration.mouse.primary : configuration.mouse.primary).customSpectrum
                    }
                    try adapter.applyFrame(frame, zones: zones)
                    if failures > 0 { log("Gradiente mouse: collegamento recuperato", false) }
                    failures = 0
                } catch {
                    failures += 1
                    if failures == 1 { log("Gradiente mouse: \(error.localizedDescription)", true) }
                    if failures >= 3 {
                        log("Gradiente mouse interrotto. In attesa della riconnessione; puoi anche premere Salva e applica.", true)
                        return
                    }
                }
            }
        } catch is CancellationError {
            // Stop and new profiles supersede every pending animation frame.
        } catch { log("Gradiente mouse: \(error.localizedDescription)", true) }
    }
}
