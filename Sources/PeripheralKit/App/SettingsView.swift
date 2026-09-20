import SwiftUI

private enum SettingsPage: String, CaseIterable, Identifiable {
    case lights = "Luci scrivania", general = "Generali", mouse = "Mouse", devices = "Dispositivi", rgb = "RGB e stop", diagnostics = "Diagnostica", about = "Informazioni"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .lights: "lightbulb.led"
        case .general: "gearshape"
        case .mouse: "computermouse"
        case .devices: "cable.connector"
        case .rgb: "moon.zzz"
        case .diagnostics: "waveform.path"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var page: SettingsPage? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $page) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .safeAreaInset(edge: .bottom) {
                Label("PeripheralKit", systemImage: "computermouse.fill")
                    .font(.caption).foregroundStyle(.secondary).padding()
            }
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text((page ?? .general).rawValue).font(.title2.bold())
                    if model.safeMode { Label("Modalità sicura: rimappatura sospesa", systemImage: "shield").foregroundStyle(.secondary) }
                }.padding(24)
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        .textSelection(.enabled).padding(.horizontal, 24).padding(.bottom, 12)
                }
                content
            }
        }
        .frame(minWidth: 740, minHeight: 540)
        .onDisappear { model.cancelRecording() }
        .onChange(of: page) { _, _ in model.cancelRecording() }
    }

    @ViewBuilder private var content: some View {
        switch page ?? .general {
        case .lights: DeskLightsView(model: model, lights: model.lights)
        case .general: general
        case .mouse: mouse
        case .devices: devices
        case .rgb: rgb
        case .diagnostics: DiagnosticsView(diagnostics: model.diagnostics)
        case .about: about
        }
    }

    private var general: some View {
        Form {
            Section {
                Toggle("Avvia al login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                Text(model.loginStatus).font(.caption).foregroundStyle(.secondary)
                Toggle("Abilita rimappatura mouse", isOn: $model.configuration.remappingEnabled).disabled(model.safeMode)
                Toggle("Abilita automazione RGB", isOn: $model.configuration.rgbEnabled)
            } header: { Text("Avvio e attività") }
            Section {
                permissionRow("Accessibilità", detail: "Per intercettare i pulsanti extra e inviare le scorciatoie.", granted: model.accessibilityGranted, action: model.requestAccessibility)
                permissionRow("Monitoraggio input", detail: "Per accedere alle interfacce HID di tastiera e mouse e controllare gli RGB.", granted: model.hidGranted, action: model.requestHID)
                Text("Nessun testo digitato viene registrato. Dopo aver concesso un permesso, macOS può richiedere di riaprire l'app.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Ricontrolla permessi") { model.refreshPermissions() }
            } header: { Text("Permessi macOS") }
            Section {
                LabeledContent("Input", value: model.inputStatus)
                Text("Le mappature si applicano a tutti i mouse, con eventuali assegnazioni per app. Puoi sospenderle subito dal menu nella barra di stato.")
                    .foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private func permissionRow(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: granted ? "checkmark.circle" : "lock")
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted { Text("Autorizzato").font(.caption).foregroundStyle(.secondary) }
            else { Button("Autorizza…", action: action) }
        }.padding(.vertical, 4)
    }

    private var mouse: some View {
        Form {
            Section {
                Toggle("Abilita rimappatura", isOn: $model.configuration.remappingEnabled).disabled(model.safeMode)
                LabeledContent("Stato", value: model.inputStatus)
                Text("Le assegnazioni valgono per tutti i mouse. Il sistema non fornisce l'origine fisica dei click a questo livello.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Pulsanti") {
                Text("Le assegnazioni per l’app attiva hanno precedenza su quelle per tutte le app. A parità, viene usata la prima.")
                    .font(.caption).foregroundStyle(.secondary)
                Menu("Aggiungi assegnazione") {
                    ForEach(3...8, id: \.self) { button in
                        Button("Pulsante \(button)") {
                            model.configuration.rules.append(Rule(name: "Pulsante \(button)", trigger: .mouseButton(button), actions: [.missionControl]))
                        }
                    }
                }
                ForEach($model.configuration.rules) { $rule in
                    MappingRow(rule: $rule) { model.configuration.rules.removeAll { $0.id == rule.id } }
                }
                if model.recording {
                    HStack {
                        Text("Premi un pulsante aggiuntivo del mouse…")
                        Spacer()
                        Button("Annulla") { model.cancelRecording() }.keyboardShortcut(.cancelAction)
                    }
                } else {
                    Button("Registra pulsante…", systemImage: "plus") { model.recordButton() }
                        .disabled(!model.accessibilityGranted || model.safeMode)
                }
                if let button = model.lastButton { Text("Ultimo pulsante rilevato: \(button)").font(.caption).foregroundStyle(.secondary) }
            }
            Section("Prova cambio Space") {
                HStack {
                    Button("Space precedente") { model.testActionRequested?(.previousSpace) }
                    Button("Space successivo") { model.testActionRequested?(.nextSpace) }
                }.disabled(!model.accessibilityGranted || model.safeMode)
                Text("La prova invia la stessa azione dei pulsanti laterali. Servono almeno due Space; arrivati al primo o all'ultimo non si passa all'estremo opposto.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Per cambiare Space, abilita Ctrl + ← e Ctrl + → in Impostazioni di Sistema → Tastiera → Abbreviazioni → Mission Control. Mission Control usa Ctrl + ↑. Puoi modificare ogni assegnazione.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var devices: some View {
        Group {
            if model.devices.isEmpty {
                ContentUnavailableView("Nessuna periferica HID rilevata", systemImage: "cable.connector", description: Text("Collega un mouse o una tastiera. L'elenco si aggiorna automaticamente ogni tre secondi."))
            } else {
                List(model.devices) { device in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(device.productName, systemImage: device.isMouse ? "computermouse" : "keyboard").font(.headline)
                        Text("\(device.manufacturer) · USB \(device.usbID)").font(.caption).foregroundStyle(.secondary)
                        Text("Interfaccia \(device.usagePage):\(device.usage) · Posizione \(device.locationID)").font(.caption).foregroundStyle(.secondary)
                        if let serial = device.serialNumber { Text("Seriale: \(serial)").font(.caption).textSelection(.enabled) }
                        if device.supportsRGB { Label("Adapter RGB disponibile", systemImage: "lightbulb").font(.caption) }
                    }.padding(.vertical, 6)
                }
            }
        }
    }

    private var rgb: some View { RGBStudioView(model: model) }

    private var about: some View {
        Form {
            Section {
                Label("PeripheralKit", systemImage: "computermouse.fill").font(.title2.bold())
                Text("Periferiche e piccole automazioni per macOS.")
                Text("Versione 0.1 · macOS 14 o successivo").foregroundStyle(.secondary)
            }
            Section {
                Text("Controllo RGB diretto per Drevo Tyrfing V2 e Razer DeathAdder V2. Nessun driver kernel, analytics o servizio di rete.")
                Text("Rimappature globali e per applicazione, scene RGB e controllo separato delle zone Razer. Le assegnazioni si applicano a tutti i mouse collegati.").foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}

private struct MappingRow: View {
    @Binding var rule: Rule
    let delete: () -> Void
    private var button: Int { if case .mouseButton(let button) = rule.trigger { button } else { 0 } }
    private var applicationName: String {
        for condition in rule.conditions {
            if case .application(let id) = condition {
                return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent ?? id
            }
        }
        return "Tutte le applicazioni"
    }
    private var actionKind: Binding<Int> {
        Binding(get: {
            switch rule.actions.first {
            case .previousSpace: 0
            case .nextSpace: 1
            case .missionControl: 2
            default: 3
            }
        }, set: { kind in
            rule.actions = [kind == 0 ? .previousSpace : kind == 1 ? .nextSpace : kind == 2 ? .missionControl : .shortcut(KeyboardShortcut())]
        })
    }
    private var shortcut: Binding<KeyboardShortcut> {
        Binding(get: { if case .shortcut(let value) = rule.actions.first { value } else { KeyboardShortcut() } }, set: { rule.actions = [.shortcut($0)] })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Pulsante \(button)", isOn: $rule.enabled)
                Spacer()
                Button(role: .destructive, action: delete) { Image(systemName: "trash") }
                    .buttonStyle(.borderless).help("Rimuovi assegnazione").accessibilityLabel("Rimuovi pulsante \(button)")
            }
            Picker("Azione", selection: actionKind) {
                Text("Space precedente · ⌃←").tag(0)
                Text("Space successivo · ⌃→").tag(1)
                Text("Mission Control · ⌃↑").tag(2)
                Text("Scorciatoia personalizzata").tag(3)
            }
            if actionKind.wrappedValue == 3 {
                ShortcutEditor(shortcut: shortcut)
            }
            HStack {
                Text(applicationName).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Scegli app…") {
                    let panel = NSOpenPanel()
                    panel.directoryURL = URL(fileURLWithPath: "/Applications")
                    panel.allowedContentTypes = [.applicationBundle]
                    panel.canChooseDirectories = false
                    panel.begin { response in
                        guard response == .OK, let url = panel.url,
                              let id = Bundle(url: url)?.bundleIdentifier else { return }
                        rule.conditions.removeAll { if case .application = $0 { true } else { false } }
                        rule.conditions.append(.application(id))
                    }
                }
                if rule.conditions.contains(where: { if case .application = $0 { true } else { false } }) {
                    Button("Tutte le app") { rule.conditions.removeAll { if case .application = $0 { true } else { false } } }
                }
            }
            Toggle("Consuma evento originale", isOn: $rule.consumeOriginalEvent)
                .font(.caption)
        }.padding(.vertical, 6)
    }
}

private struct ShortcutEditor: View {
    @Binding var shortcut: KeyboardShortcut
    var body: some View {
        VStack(alignment: .leading) {
            Stepper("Codice tasto macOS: \(shortcut.keyCode)", value: $shortcut.keyCode, in: 0...127)
            HStack {
                Toggle("⌃ Control", isOn: $shortcut.control)
                Toggle("⌥ Option", isOn: $shortcut.option)
                Toggle("⇧ Shift", isOn: $shortcut.shift)
                Toggle("⌘ Command", isOn: $shortcut.command)
            }.toggleStyle(.checkbox)
            Text("Codici: ← 123 · → 124 · ↓ 125 · ↑ 126 · Invio 36 · Spazio 49. Sono codici fisici, indipendenti dall'etichetta del tasto.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct DiagnosticsView: View {
    @ObservedObject var diagnostics: Diagnostics
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ultimi 300 eventi, solo in memoria.").foregroundStyle(.secondary)
                Spacer()
                Button("Svuota") { diagnostics.clear() }
            }.padding(.horizontal, 24)
            List(diagnostics.entries.reversed()) { entry in
                HStack(alignment: .top, spacing: 12) {
                    Text(entry.date, style: .time).monospacedDigit().foregroundStyle(.secondary)
                    if entry.isError { Image(systemName: "exclamationmark.triangle").foregroundStyle(.red) }
                    Text(entry.message).textSelection(.enabled)
                }.font(.caption).padding(.vertical, 3)
            }
        }
    }
}

private struct DeskLightsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var lights: HappyLighting
    @State private var identifier = ""

    private var color: Binding<Color> {
        Binding(get: { .rgb(model.configuration.deskLight?.color ?? "#FF00FF") }, set: { value in
            guard let hex = value.rgbHex else { return }
            model.configuration.deskLight?.color = hex
        })
    }

    var body: some View {
        Form {
            Section("Striscia HappyLighting") {
                if let light = model.configuration.deskLight {
                    LabeledContent("Dispositivo", value: light.name)
                    Text(light.identifier.uuidString).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    ColorPicker("Colore", selection: color, supportsOpacity: false)
                    HStack {
                        Button("Accendi / applica colore") { model.setDeskLight(on: true) }
                        Button("Spegni") { model.setDeskLight(on: false) }
                    }.disabled(lights.busy)
                    Text("Il colore viene salvato e applicato all’accensione. Lo stato fisico delle luci non viene letto dal dispositivo.").font(.caption).foregroundStyle(.secondary)
                    Toggle("Spegni durante lo stop", isOn: Binding(
                        get: { model.configuration.deskLight?.sleepEnabled == true },
                        set: { model.configuration.deskLight?.sleepEnabled = $0 }
                    ))
                    Text("Segue le opzioni di stop e ripristino in RGB e stop, indipendentemente dall’automazione USB. Al risveglio riaccende solo le luci accese dall’app. Lo spegnimento prima dello stop completo dipende dal tempo disponibile per il Bluetooth.").font(.caption).foregroundStyle(.secondary)
                    if light.requestedOn == nil {
                        Text("Premi Accendi o Spegni per impostare lo stato da ricordare.").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Alimenta la striscia, avvicinala al Mac e cerca i dispositivi. Seleziona il controller usato da HappyLighting.")
                }
                Text(lights.status).foregroundStyle(.secondary)
                if let error = lights.error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).textSelection(.enabled)
                    Button("Impostazioni Bluetooth") { model.openPrivacy("Privacy_Bluetooth") }
                }
                if lights.busy { Button("Annulla") { model.deskLightCancelRequested?() } }
            }
            Section("Seleziona dispositivo") {
                Button("Cerca strisce Bluetooth") { lights.scan() }.disabled(lights.busy)
                ForEach(lights.devices) { device in
                    Button {
                        model.configuration.deskLight = DeskLightConfiguration(identifier: device.id, name: device.name)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text(device.id.uuidString).font(.caption).foregroundStyle(.secondary)
                        }
                    }.disabled(lights.busy)
                }
                DisclosureGroup("Configura tramite identificatore macOS") {
                    TextField("UUID Bluetooth", text: $identifier)
                    Button("Usa identificatore") {
                        if let id = UUID(uuidString: identifier.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            model.configuration.deskLight = DeskLightConfiguration(identifier: id, name: "HappyLighting")
                        }
                    }.disabled(lights.busy || UUID(uuidString: identifier.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                    Text("Puoi usare l’UUID del precedente script Python. Non è l’indirizzo MAC.").font(.caption).foregroundStyle(.secondary)
                }
                if model.configuration.deskLight != nil {
                    Button("Dimentica striscia", role: .destructive) { model.configuration.deskLight = nil }.disabled(lights.busy)
                }
            }
        }.formStyle(.grouped)
    }
}
