import AppKit

@MainActor
final class AppRuntime {
    private let model: AppModel
    private let input = InputEventEngine()
    private let system = SystemEventMonitor()
    private let actions: any ActionExecutor
    private let rgb: RGBSleepCoordinator
    private let deskLight: DeskLightSleepCoordinator
    private var policy = SleepPolicy()
    private var powerTask: Task<Void, Never>?
    private var preview: (Configuration, RGBProfileTarget)?
    private var captureTimeout: Task<Void, Never>?

    init(model: AppModel, actions: any ActionExecutor = ActionEngine()) {
        self.model = model
        self.actions = actions
        let diagnostics = model.diagnostics
        deskLight = DeskLightSleepCoordinator(transport: model.lights) { message, error in
            diagnostics.record(message, error: error, persistent: true)
        }
        rgb = RGBSleepCoordinator { message, error in
            Task { @MainActor in diagnostics.record(message, error: error, persistent: true) }
        }
    }

    func start() {
        bindModelActions()
        bindInputEvents()
        bindSystemEvents()
        input.foregroundApplication = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        system.start()
        updateConfiguration()
        resumeSavedMouseCycleIfNeeded()
    }

    private func bindModelActions() {
        model.previewCancelRequested = { [weak self] in
            guard let self, let preview = self.preview else { return }
            self.model.previewRequested?(nil, preview.1)
        }
        model.previewRequested = { [weak self] configuration, target in
            guard let self else { return }
            self.preview = configuration.map { ($0, target) }
            let value = configuration ?? self.model.configuration.rgb
            let previous = self.powerTask
            self.powerTask = Task { [weak self] in
                await previous?.value
                guard let self else { return }
                let result = await self.rgb.applyProfile(value, target: target)
                if !result.succeeded { self.model.rgbApplyResult = result; self.model.errorMessage = result.failures.joined(separator: "\n") }
            }
        }
        model.devicesChanged = { [weak self] before, after in
            guard let self, self.model.hidGranted,
                  self.model.configuration.restoreOnReconnect != false else { return }
            let old = Set(before.map(\.id))
            let targets = Set(after.lazy
                .filter { !old.contains($0.id) }
                .compactMap { RGBProfileTarget.matching($0)?.adapterID })
            guard !targets.isEmpty else { return }
            let configuration = self.preview?.0 ?? self.model.configuration.rgb
            let previous = self.powerTask
            self.powerTask = Task { [weak self] in
                await previous?.value
                await self?.rgb.reconnect(targets, configuration: configuration)
            }
        }
        model.rgbApplyRequested = { [weak self] configuration, target in
            guard let self, !self.model.rgbApplying else { return }
            self.preview = nil
            self.model.rgbApplying = true
            self.model.rgbApplyResult = nil
            let previous = self.powerTask
            self.powerTask = Task { [weak self] in
                await previous?.value
                guard let self else { return }
                var sent = configuration
                if target == nil { sent.keyboard.enabled = true; sent.mouse.enabled = true }
                let result = await self.rgb.applyProfile(sent, target: target)
                self.model.rgbApplying = false
                if self.model.configuration.rgb == configuration { self.model.rgbApplyResult = result }
            }
        }
        model.deskLightRequested = { [weak self] light, on in self?.deskLight.manual(light, on: on) }
        model.deskLightCancelRequested = { [weak self] in self?.deskLight.cancel() }
        model.testActionRequested = { [weak self] action in
            guard let self, !self.model.safeMode else { return }
            do {
                try self.actions.execute([action])
                self.model.diagnostics.record("Prova: scorciatoia inviata")
            } catch { self.model.report(error) }
        }
        model.configurationChanged = { [weak self] in self?.updateConfiguration() }
        model.captureRequested = { [weak self] recording in
            guard let self else { return }
            self.captureTimeout?.cancel()
            self.input.router.recording = recording
            self.updateInput()
            if recording && self.model.recording {
                self.captureTimeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                    self?.model.cancelRecording()
                }
            }
        }
    }

    private func bindInputEvents() {
        input.onButton = { [weak self] button in
            self?.model.lastButton = button
            self?.model.diagnostics.record("Pulsante mouse \(button)")
        }
        input.onCapture = { [weak self] button in
            self?.captureTimeout?.cancel()
            self?.model.captured(button)
        }
        input.onRule = { [weak self] rule in
            guard let self else { return }
            // The down was already accepted by the rule engine inside the tap.
            // Dispatch its immutable action snapshot even if preferences changed.
            do {
                try self.actions.execute(rule.actions)
                self.model.diagnostics.record("Scorciatoia inviata: \(rule.name)")
            } catch { self.model.report(error) }
        }
        input.onTapRecovery = { [weak self] in self?.model.diagnostics.record("Monitor mouse riattivato da macOS") }
    }

    private func bindSystemEvents() {
        system.onEvent = { [weak self] event in
            guard let self else { return }
            self.model.diagnostics.record("Sistema: \(event.rawValue)", persistent: event != .applicationChanged && event != .spaceChanged)
            self.input.foregroundApplication = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            self.policy.receive(event)
            self.updatePower()
        }
    }

    private func resumeSavedMouseCycleIfNeeded() {
        guard model.hidGranted, model.configuration.restoreOnReconnect == false else { return }
        let previous = powerTask
        let configuration = model.configuration.rgb
        Task { [weak self] in
            await previous?.value
            await self?.rgb.resumeSavedMouseCycle(configuration)
        }
    }

    private func updateConfiguration() {
        input.router.rules = model.configuration.rules
        updateInput()
        updatePower()
    }

    private func updateInput() {
        input.router.enabled = model.remappingActive
        if model.safeMode {
            input.router.recording = false
            model.inputStatus = "Modalità sicura"
        } else if !model.accessibilityGranted {
            input.router.recording = false
            model.recording = false
            model.inputStatus = "Accessibilità da autorizzare"
        } else if !input.start() {
            input.router.recording = false
            model.recording = false
            model.inputStatus = "Monitor non disponibile; riapri l'app dopo aver autorizzato Accessibilità"
        } else {
            model.inputStatus = model.configuration.remappingEnabled ? "In ascolto · rimappatura attiva" : "In ascolto · rimappatura disattivata"
        }
    }

    private func updatePower() {
        let configuration = model.configuration
        deskLight.update(configuration: configuration, policy: policy)
        let sleep = policy.shouldSleep(configuration: configuration)
        if sleep && !model.rgbSleeping {
            model.previewCancellation += 1
            preview = nil
        }
        model.rgbSleeping = sleep
        let previous = powerTask
        let rgb = self.rgb
        // Preserve notification ordering across the actor boundary.
        powerTask = Task {
            await previous?.value
            await rgb.transition(toSleep: sleep, configuration: configuration)
        }
    }

    func stop() {
        let rgb = self.rgb
        Task { await rgb.shutdown() }
        deskLight.cancel()
        captureTimeout?.cancel()
        input.stop()
        system.stop()
    }
}
