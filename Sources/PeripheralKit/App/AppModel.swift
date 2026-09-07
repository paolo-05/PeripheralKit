import AppKit
@preconcurrency import ApplicationServices
import IOKit.hid
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var configuration = AppConfiguration() {
        didSet {
            guard !loading else { return }
            do {
                guard !configurationReadFailed else { throw PeripheralKitError.invalidConfiguration("Configurazione non salvata: correggi il file indicato e riapri l'app.") }
                try store.save(configuration)
                errorMessage = nil
            } catch { report(error) }
            configurationChanged?()
        }
    }
    @Published var errorMessage: String?
    @Published var accessibilityGranted = false
    @Published var hidGranted = false
    @Published var loginEnabled = false
    @Published var loginStatus = ""
    @Published var devices: [PeripheralDevice] = []
    @Published var inputStatus = "Rimappatura disattivata"
    @Published var recording = false
    @Published var lastButton: Int?
    let lights = HappyLighting()
    let diagnostics = Diagnostics()
    let safeMode: Bool
    let store = ConfigurationStore()
    var configurationChanged: (() -> Void)?
    var testActionRequested: ((Action) -> Void)?
    var captureRequested: ((Bool) -> Void)?
    private var loading = true
    private var configurationReadFailed = false
    private var refreshTask: Task<Void, Never>?

    init(safeMode: Bool) {
        self.safeMode = safeMode
        do {
            configuration = try store.load()
            if !FileManager.default.fileExists(atPath: store.url.path) { try store.save(configuration) }
        }
        catch {
            configurationReadFailed = true
            configuration.rgbEnabled = false
            report(error)
        }
        loading = false
        refreshPermissions()
        diagnostics.record(safeMode ? "Avvio in modalità sicura: rimappatura sospesa" : "PeripheralKit avviato")
        if configurationReadFailed { diagnostics.record("File da correggere: \(store.url.path)", error: true) }
    }

    var remappingActive: Bool { configuration.remappingEnabled && !safeMode && accessibilityGranted }

    func startRefreshing() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refreshPermissions()
                await self.refreshDevices()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func refreshPermissions() {
        let granted = AXIsProcessTrusted()
        let changed = granted != accessibilityGranted
        accessibilityGranted = granted
        hidGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        loginEnabled = SMAppService.mainApp.status == .enabled
        switch SMAppService.mainApp.status {
        case .enabled: loginStatus = "Attivo"
        case .requiresApproval: loginStatus = "Da approvare nelle Impostazioni di Sistema"
        case .notFound: loginStatus = isInstalled ? "Elemento di login non trovato da macOS" : "Installa l'app in Applicazioni"
        default: loginStatus = "Disattivato"
        }
        if changed { configurationChanged?() }
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        openPrivacy("Privacy_Accessibility")
    }

    func requestHID() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        openPrivacy("Privacy_ListenEvent")
    }

    func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshPermissions()
        } catch { report(error) }
    }

    func refreshDevices() async {
        do {
            let found = try await Task.detached(priority: .utility) { try HIDDeviceManager().devices() }.value
            let before = Set(devices.map(\.id)), after = Set(found.map(\.id))
            for device in found where !before.contains(device.id) { diagnostics.record("HID collegato: \(device.productName) [\(device.usbID)]") }
            for device in devices where !after.contains(device.id) { diagnostics.record("HID scollegato: \(device.productName)") }
            if devices != found { devices = found }
        } catch { report(error) }
    }

    var isInstalled: Bool {
        let parent = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL
        return parent == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardizedFileURL
            || parent == URL(fileURLWithPath: "/Applications", isDirectory: true).standardizedFileURL
    }

    func setDeskLight(on: Bool) {
        guard let light = configuration.deskLight else { return }
        do { lights.send(to: light.identifier, on: on, color: try RGBColor(hex: light.color)) }
        catch { report(error) }
    }

    func recordButton() { recording = true; captureRequested?(true) }
    func cancelRecording() { recording = false; captureRequested?(false) }
    func captured(_ button: Int) {
        lastButton = button
        recording = false
        if !configuration.rules.contains(where: { $0.trigger == .mouseButton(button) }) {
            configuration.rules.append(Rule(name: "Pulsante \(button)", trigger: .mouseButton(button), actions: [.missionControl]))
        }
        diagnostics.record("Catturato pulsante \(button); origine fisica non disponibile")
    }

    func report(_ error: Error) {
        errorMessage = error.localizedDescription
        diagnostics.record(error.localizedDescription, error: true)
    }
}
