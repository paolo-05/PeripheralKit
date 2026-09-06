import AppKit

@MainActor
final class AppRuntime {
    private let model: AppModel
    private let input = InputEventEngine()
    private let system = SystemEventMonitor()
    private let actions: any ActionExecutor
    private let rgb: RGBSleepCoordinator
    private var policy = SleepPolicy()
    private var powerTask: Task<Void, Never>?
    private var captureTimeout: Task<Void, Never>?
    private var legacyAgentPresent: Bool {
        FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/com.local.mksleep-rgb.plist").path)
    }

    init(model: AppModel, actions: any ActionExecutor = ActionEngine()) {
        self.model = model
        self.actions = actions
        let diagnostics = model.diagnostics
        rgb = RGBSleepCoordinator { message, error in
            Task { @MainActor in diagnostics.record(message, error: error) }
        }
    }

    func start() {
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
                self.model.diagnostics.record("Regola eseguita: \(rule.name)")
            } catch { self.model.report(error) }
        }
        input.onTapRecovery = { [weak self] in self?.model.diagnostics.record("Monitor mouse riattivato da macOS") }
        system.onEvent = { [weak self] event in
            guard let self else { return }
            self.model.diagnostics.record("Sistema: \(event.rawValue)")
            self.input.foregroundApplication = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            self.policy.receive(event)
            self.updatePower()
        }
        input.foregroundApplication = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        system.start()
        updateConfiguration()
        if legacyAgentPresent {
            model.diagnostics.record("RGB sospeso: è ancora installato il LaunchAgent MKSleepRGB. Completa la migrazione con l'installer di PeripheralKit.", error: true)
            model.legacyRGBWarning = true
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
        guard !legacyAgentPresent else { return }
        model.legacyRGBWarning = false
        let configuration = model.configuration
        let sleep = policy.shouldSleep(configuration: configuration)
        let previous = powerTask
        let rgb = self.rgb
        // Preserve notification ordering across the actor boundary.
        powerTask = Task {
            await previous?.value
            await rgb.transition(toSleep: sleep, configuration: configuration)
        }
    }

    func stop() {
        captureTimeout?.cancel()
        input.stop()
        system.stop()
    }
}
