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
        Binding(get: {
            let rgb = (try? RGBColor(hex: model.configuration.deskLight?.color ?? "#FF00FF"))
            return Color(red: Double(rgb?.red ?? 255) / 255, green: Double(rgb?.green ?? 0) / 255, blue: Double(rgb?.blue ?? 255) / 255)
        }, set: { value in
            guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return }
            model.configuration.deskLight?.color = String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
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

private extension KeyboardConfiguration.Mode {
    var title: String {
        switch self {
        case .static: "Colore fisso"
        case .rainbow: "Arcobaleno"
        case .breathing: "Respiro"
        case .stream: "Scorrimento"
        case .radar: "Radar"
        case .memory: "Profilo in memoria"
        }
    }
}

private extension MouseConfiguration.Mode {
    var title: String {
        switch self {
        case .spectrum: "Ciclo colori"
        case .static: "Colore fisso"
        case .breathing: "Respiro"
        }
    }
}

private struct RGBStudioView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var lights: HappyLighting
    @State private var device: RGBProfileTarget = .keyboard
    @State private var section = 0
    @State private var draft: Configuration
    @State private var appliedDevice: RGBProfileTarget?
    @State private var invalidPrimary = false
    @State private var invalidSecondary = false
    @State private var invalidGradient = false
    @State private var paletteReset = UUID()
    @State private var zone = 0
    @State private var live = false
    @State private var previewTask: Task<Void, Never>?
    @State private var sceneName = ""

    init(model: AppModel) {
        self.model = model
        self.lights = model.lights
        _draft = State(initialValue: model.configuration.rgb)
    }

    private var keyboard: Bool { device == .keyboard }
    private var modified: Bool {
        keyboard ? draft.keyboard != model.configuration.rgb.keyboard : draft.mouse != model.configuration.rgb.mouse
    }
    private var included: Binding<Bool> {
        keyboard ? $draft.keyboard.enabled : $draft.mouse.enabled
    }
    private var editedMouse: Binding<MouseConfiguration> {
        Binding(get: {
            if zone == 1, let logo = draft.mouse.logo {
                var value = draft.mouse
                value.primary = logo
                return value
            }
            return draft.mouse
        }, set: { value in
            if zone == 1 && draft.mouse.logo != nil { draft.mouse.logo = value.primary }
            else { draft.mouse.primary = value.primary }
        })
    }
    private var effect: String { keyboard ? draft.keyboard.mode.rawValue : editedMouse.wrappedValue.mode.rawValue }
    private var color: Binding<String> { keyboard ? $draft.keyboard.color : editedMouse.color }
    private var usesColor: Bool { !["rainbow", "spectrum", "memory"].contains(effect) }
    private var animated: Bool { ["breathing", "stream", "radar"].contains(effect) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sezione RGB", selection: $section) {
                Text("Illuminazione").tag(0)
                Text("Stop e risveglio").tag(1)
                Text("Scene").tag(2)
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 24).padding(.bottom, 16)
            if section == 0 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Picker("Periferica", selection: $device) {
                            Label("Tastiera Drevo", systemImage: "keyboard").tag(RGBProfileTarget.keyboard)
                            Label("Mouse Razer", systemImage: "computermouse").tag(RGBProfileTarget.mouse)
                        }.pickerStyle(.segmented).labelsHidden()
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(keyboard ? "Tyrfing V2" : "DeathAdder V2").font(.title2.weight(.semibold))
                                Text(keyboard ? "DREVO · Illuminazione della tastiera" : "RAZER · Rotella e logo").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Label(connected ? "Collegato" : "Non rilevato", systemImage: connected ? "circle.fill" : "circle")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if !keyboard {
                            Toggle("Configura logo e rotella separatamente", isOn: Binding(get: { draft.mouse.logo != nil }, set: {
                                draft.mouse.logo = $0 ? draft.mouse.primary : nil
                                zone = 0
                            }))
                            if draft.mouse.logo != nil {
                                Picker("Zona", selection: $zone) {
                                    Text("Rotella").tag(0)
                                    Text("Logo").tag(1)
                                }.pickerStyle(.segmented)
                            }
                        }
                        RGBDevicePreview(keyboard: keyboard, effect: effect, hex: color.wrappedValue,
                                         brightness: keyboard ? Double(draft.keyboard.brightness) / 100 : 1,
                                         spectrumPalette: keyboard ? nil : editedMouse.wrappedValue.spectrumColors,
                                         mouseProfile: keyboard ? nil : draft.mouse)
                            .frame(height: keyboard ? 140 : 180)
                        HStack(alignment: .top, spacing: 24) {
                            effects.frame(width: 165)
                            VStack(alignment: .leading, spacing: 18) {
                                Text("PERSONALIZZA").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                if !keyboard && effect == "spectrum" {
                                    RGBGradientEditor(mouse: editedMouse, invalid: $invalidGradient).id(paletteReset)
                                } else if usesColor { RGBPalette(title: "Colore", hex: color, invalid: $invalidPrimary).id("\(device)-\(paletteReset)") }
                                else {
                                    Text(effect == "memory" ? "Richiama il profilo memorizzato nella tastiera." : "Questo effetto gestisce automaticamente i colori.")
                                        .font(.callout).foregroundStyle(.secondary)
                                }
                                if keyboard {
                                    percentageSlider("Luminosità", value: $draft.keyboard.brightness)
                                    if animated {
                                        percentageSlider("Velocità", value: $draft.keyboard.speed)
                                        RGBPalette(title: "Secondo colore", hex: $draft.keyboard.secondaryColor, invalid: $invalidSecondary).id(paletteReset)
                                    }
                                }
                                Toggle("Includi nello stop e nel ripristino", isOn: included).font(.callout)
                                Text(keyboard ? "Anteprima indicativa del colore. Il controllo dei singoli tasti non è ancora disponibile." : "L’anteprima è indicativa e non legge i LED. Disattivando le zone separate, entrambe seguono la rotella.")
                                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 20)
                }
                footer
            } else if section == 1 {
                sleepSettings
            } else { scenes }
        }
        .onChange(of: model.previewCancellation) { _, _ in endPreview() }
        .onDisappear { endPreview() }
        .onChange(of: draft) { _, _ in schedulePreview() }
        .onChange(of: live) { _, enabled in if enabled { schedulePreview() } else { endPreview() } }
        .onChange(of: section) { _, _ in endPreview() }
        .onChange(of: zone) { _, _ in paletteReset = UUID(); invalidPrimary = false; invalidGradient = false }
        .onChange(of: device) { old, _ in
            previewTask?.cancel()
            if live { model.previewRequested?(nil, old); live = false }
            zone = 0
            appliedDevice = nil; invalidPrimary = false; invalidSecondary = false; invalidGradient = false }
    }

    private var connected: Bool {
        model.devices.contains(where: device.matches)
    }

    private var effects: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("EFFETTI").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.bottom, 6)
            if keyboard {
                ForEach(KeyboardConfiguration.Mode.allCases, id: \.self) { mode in
                    effectButton(mode.title, value: mode.rawValue) { draft.keyboard.mode = mode }
                }
            } else {
                ForEach(MouseConfiguration.Mode.allCases, id: \.self) { mode in
                    effectButton(mode.title, value: mode.rawValue) { editedMouse.wrappedValue.mode = mode }
                }
            }
        }
    }

    private func effectButton(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon(value)).frame(width: 20)
                Text(title).font(.callout)
                Spacer(minLength: 0)
                if effect == value { Image(systemName: "checkmark").font(.caption.weight(.semibold)) }
            }.padding(.horizontal, 10).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(effect == value ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(effect == value ? .isSelected : [])
    }

    private func icon(_ value: String) -> String {
        switch value {
        case "static": "sun.max"
        case "breathing": "waveform.path"
        case "stream": "arrow.right"
        case "radar": "dot.radiowaves.left.and.right"
        case "memory": "internaldrive"
        default: "rainbow"
        }
    }

    private func percentageSlider(_ title: String, value: Binding<Int>) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                Text("\(value.wrappedValue)%").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: 0...100, step: 1)
                .accessibilityLabel(title).accessibilityValue("\(value.wrappedValue)%")
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            if appliedDevice == device, !modified, let result = model.rgbApplyResult {
                ForEach(result.successes, id: \.self) { name in
                    Label("Profilo inviato: \(name)", systemImage: "checkmark.circle").font(.caption)
                }
                ForEach(Array(result.failures.enumerated()), id: \.offset) { _, message in
                    Label(message, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red)
                }
            }
            Toggle("Anteprima sulle periferiche", isOn: $live)
                .font(.caption).disabled(model.rgbSleeping || !model.hidGranted || model.rgbApplying)
            if live {
                Text("Modifiche temporanee. Annulla o chiudi l’editor per ripristinare il profilo salvato.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(modified ? "Modifiche in anteprima" : "Profilo salvato").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Annulla modifiche") {
                    endPreview()
                    if keyboard { draft.keyboard = model.configuration.rgb.keyboard }
                    else { draft.mouse = model.configuration.rgb.mouse }
                    invalidPrimary = false
                    invalidSecondary = false
                    invalidGradient = false
                    paletteReset = UUID()
                }.disabled((!modified && !invalidPrimary && !invalidSecondary && !invalidGradient) || model.rgbApplying)
                Button(model.rgbApplying ? "Invio…" : "Salva e applica") { apply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.rgbApplying || model.rgbSleeping || !model.hidGranted || invalidPrimary || invalidSecondary || invalidGradient)
            }
            if !model.hidGranted {
                Text("Autorizza Monitoraggio input in Generali per applicare il profilo.").font(.caption).foregroundStyle(.secondary)
            } else if model.rgbSleeping {
                Text("Riattiva gli schermi prima di applicare il profilo.").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.horizontal, 24).padding(.bottom, 16)
    }

    private func schedulePreview() {
        previewTask?.cancel()
        guard live, !invalidPrimary, !invalidSecondary, !invalidGradient else { return }
        let value = draft, target = device
        let cancellation = model.previewCancellation
        previewTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled, model.previewCancellation == cancellation else { return }
            model.previewRequested?(value, target)
        }
    }

    private func endPreview() {
        previewTask?.cancel()
        if live { model.previewRequested?(nil, device) }
        live = false
    }

    private var scenes: some View {
        Form {
            Section("Salva la configurazione attuale") {
                TextField("Nome scena", text: $sceneName)
                Button("Salva scena") { model.saveScene(name: sceneName); sceneName = "" }
                    .disabled(sceneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Include i profili RGB salvati e l’ultimo stato richiesto alle luci scrivania. Applica prima le modifiche dell’editor.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Scene salvate") {
                if let result = model.rgbApplyResult {
                    ForEach(result.successes, id: \.self) { Text("Profilo inviato: \($0)").font(.caption) }
                    ForEach(result.failures, id: \.self) { Text($0).font(.caption).foregroundStyle(.red) }
                }
                if model.configuration.deskLight != nil {
                    Text(lights.error ?? lights.status).font(.caption).foregroundStyle(.secondary)
                }
                if (model.configuration.scenes ?? []).isEmpty {
                    Text("Crea una scena per richiamarla anche dalla barra menu.").foregroundStyle(.secondary)
                }
                ForEach(model.configuration.scenes ?? []) { scene in
                    HStack {
                        Text(scene.name)
                        Spacer()
                        Button("Applica") { model.applyScene(scene); draft = model.configuration.rgb }
                            .disabled(model.rgbApplying || model.rgbSleeping || model.lights.busy)
                        Button(role: .destructive) { model.configuration.scenes?.removeAll { $0.id == scene.id } } label: {
                            Image(systemName: "trash")
                        }.accessibilityLabel("Elimina scena \(scene.name)")
                    }
                }
            }
        }.formStyle(.grouped)
    }

    private func apply() {
        previewTask?.cancel()
        live = false
        if keyboard { model.configuration.rgb.keyboard = draft.keyboard }
        else { model.configuration.rgb.mouse = draft.mouse }
        appliedDevice = device
        model.applyRGBProfile(target: device)
    }

    private var sleepSettings: some View {
        Form {
            Section("Automazione USB") {
                Toggle("Ripristina quando colleghi le periferiche", isOn: Binding(get: {
                    model.configuration.restoreOnReconnect != false
                }, set: { model.configuration.restoreOnReconnect = $0 }))
                Toggle("Abilita automazione RGB USB", isOn: $model.configuration.rgbEnabled)
                Text("Le periferiche incluse si spengono durante lo stop e recuperano il profilo salvato al risveglio.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Comportamento condiviso") {
                Toggle("Spegni quando il Mac va in stop", isOn: $model.configuration.systemSleepEnabled)
                Toggle("Spegni quando gli schermi si spengono", isOn: $model.configuration.displaySleepEnabled)
                Toggle("Ripristina al risveglio", isOn: $model.configuration.restoreOnWake)
                Stepper(value: $model.configuration.rgb.wakeDelaySeconds, in: 0...30, step: 0.25) {
                    LabeledContent("Attesa dopo il risveglio", value: String(format: "%.2f s", model.configuration.rgb.wakeDelaySeconds))
                }
                Text("Queste opzioni valgono anche per le luci scrivania, se l’automazione è attiva nella loro pagina.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}

private struct RGBPalette: View {
    let title: String
    @Binding var hex: String
    @State private var text = ""
    @Binding var invalid: Bool
    private let colors = ["#FF3B30", "#FF9500", "#FFD60A", "#30D158", "#0A84FF", "#BF5AF2", "#FF00FF", "#FFFFFF"]
    private var selection: Binding<Color> {
        Binding(get: { Self.color(hex) }, set: { color in
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            hex = String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ColorPicker(title, selection: selection, supportsOpacity: false)
            HStack(spacing: 7) {
                ForEach(colors, id: \.self) { value in
                    Button { hex = value } label: {
                        Circle().fill(Self.color(value)).frame(width: 20, height: 20)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.15)))
                            .padding(3)
                            .overlay(Circle().strokeBorder(hex.uppercased() == value ? Color.accentColor : Color.clear, lineWidth: 2))
                    }.buttonStyle(.plain).accessibilityLabel("\(title), \(value)")
                        .accessibilityAddTraits(hex.uppercased() == value ? .isSelected : [])
                }
            }
            HStack {
                Text("HEX").font(.caption).foregroundStyle(.secondary)
                TextField("#RRGGBB", text: $text).textFieldStyle(.roundedBorder).font(.callout.monospaced())
                    .onChange(of: text) { _, value in
                        guard let rgb = try? RGBColor(hex: value) else { invalid = true; return }
                        invalid = false
                        let normalized = String(format: "#%02X%02X%02X", rgb.red, rgb.green, rgb.blue)
                        if normalized != hex { hex = normalized }
                    }.accessibilityLabel("\(title), valore esadecimale")
            }
            if invalid { Text("Inserisci sei cifre esadecimali, ad esempio #FF00FF.").font(.caption).foregroundStyle(.red) }
        }
        .onAppear { text = hex; invalid = false }
        .onDisappear { invalid = false }
        .onChange(of: hex) { _, value in text = value; invalid = false }
    }
    nonisolated static func color(_ hex: String) -> Color {
        guard let rgb = try? RGBColor(hex: hex) else { return .secondary }
        return Color(red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255)
    }
}

private struct RGBDevicePreview: View {
    let keyboard: Bool
    let effect: String
    let hex: String
    let brightness: Double
    let spectrumPalette: [String]?
    let mouseProfile: MouseConfiguration?
    private var spectrum: Bool { ["rainbow", "spectrum"].contains(effect) }
    var body: some View {
        Canvas { context, size in
            let color = RGBPalette.color(hex).opacity(max(0, min(1, brightness)))
            if keyboard {
                let unit = min((size.width - 28) / 20, (size.height - 24) / 6.8)
                let origin = CGPoint(x: (size.width - unit * 19.6) / 2, y: (size.height - unit * 6.4) / 2)
                let body = CGRect(x: origin.x - 8, y: origin.y - 8, width: unit * 19.6 + 16, height: unit * 6.4 + 16)
                context.fill(Path(roundedRect: body, cornerRadius: 10), with: .color(Color(nsColor: .controlBackgroundColor)))
                for row in 0..<6 {
                    for column in 0..<18 {
                        if row == 0 && [1, 6, 11, 15].contains(column) { continue }
                        if row == 5 && column > 3 && column < 10 { continue }
                        if row >= 3 && column == 15 { continue }
                        if row == 4 && column > 15 && column != 16 { continue }
                        let width = row == 5 && column == 3 ? unit * 7 - 3 : unit - 3
                        let x = origin.x + Double(column) * unit + (column >= 15 ? unit * 0.65 : 0)
                        let y = origin.y + Double(row) * unit + (row > 0 ? unit * 0.35 : 0)
                        let key = Path(roundedRect: CGRect(x: x, y: y, width: width, height: unit - 3), cornerRadius: 3)
                        let tint = effect == "memory" ? Color.secondary : spectrum ? Color(hue: Double(column) / 18, saturation: 0.75, brightness: 1).opacity(brightness) : color
                        context.fill(key, with: .color(Color(nsColor: .windowBackgroundColor)))
                        context.stroke(key, with: .color(tint.opacity(0.7)), lineWidth: 1)
                        let rows = ["E 1234 5678 901  P", "1234567890-=   IHP", "QWERTYUIOP[]  DED", "ASDFGHJKL;'    ↑  ", "ZXCVBNM,./     ←↓→", "⌃⌥⌘        ⌘⌥⌃   "]
                        let labels = Array(rows[row])
                        if column < labels.count, labels[column] != " " {
                            context.draw(Text(String(labels[column])).font(.system(size: unit * 0.43, weight: .medium, design: .monospaced)).foregroundColor(tint),
                                         at: CGPoint(x: x + width / 2, y: y + (unit - 3) / 2))
                        }
                    }
                }
            } else {
                let w = 100.0, h = min(size.height - 16, 172)
                let x = (size.width - w) / 2, y = (size.height - h) / 2
                let body = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 44)
                context.fill(body, with: .color(Color(nsColor: .controlBackgroundColor)))
                context.stroke(body, with: .color(Color.primary.opacity(0.18)), lineWidth: 1)
                var seam = Path()
                seam.move(to: CGPoint(x: x + w / 2, y: y + 8))
                seam.addLine(to: CGPoint(x: x + w / 2, y: y + h * 0.43))
                context.stroke(seam, with: .color(Color.primary.opacity(0.15)), lineWidth: 1)
                func zoneColor(_ profile: MouseZoneConfiguration?) -> Color {
                    guard let profile else { return color }
                    if profile.mode == .spectrum { return profile.spectrumColors?.first.map(RGBPalette.color) ?? .green }
                    return RGBPalette.color(profile.color)
                }
                let tint = zoneColor(mouseProfile?.primary)
                let logoTint = zoneColor(mouseProfile?.logo ?? mouseProfile?.primary)
                context.fill(Path(roundedRect: CGRect(x: x + 44, y: y + 23, width: 12, height: 30), cornerRadius: 5), with: .color(tint))
                let mark = Text("R").font(.system(size: 26, weight: .medium, design: .rounded)).foregroundColor(logoTint)
                context.draw(mark, at: CGPoint(x: x + w / 2, y: y + h * 0.72))
                context.draw(Text("Rotella").font(.caption).foregroundColor(.secondary), at: CGPoint(x: x + w + 42, y: y + 38))
                context.draw(Text("Logo").font(.caption).foregroundColor(.secondary), at: CGPoint(x: x + w + 42, y: y + h * 0.72))
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Anteprima indicativa \(keyboard ? "tastiera" : "mouse"), effetto \(effect)")
        .accessibilityElement(children: .ignore)
    }
}

private struct RGBGradientEditor: View {
    @Binding var mouse: MouseConfiguration
    @Binding var invalid: Bool
    @State private var selected = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var colors: [String] { mouse.spectrumColors ?? [] }
    private var custom: Binding<Bool> {
        Binding(get: { mouse.spectrumColors != nil }, set: { enabled in
            mouse.spectrumColors = enabled ? [mouse.color, "#BF5AF2", "#30D158"] : nil
            selected = 0
            invalid = false
        })
    }
    private var selectedColor: Binding<String> {
        Binding(get: { colors.indices.contains(selected) ? colors[selected] : "#FFFFFF" }, set: { color in
            guard colors.indices.contains(selected) else { return }
            mouse.spectrumColors?[selected] = color
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Palette", selection: custom) {
                Text("Spectrum completo").tag(false)
                Text("Gradiente personalizzato").tag(true)
            }
            if custom.wrappedValue {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: (colors + Array(colors.prefix(1))).map(RGBPalette.color), startPoint: .leading, endPoint: .trailing))
                    .frame(height: 22).accessibilityLabel("Gradiente ciclico di \(colors.count) colori")
                HStack(spacing: 6) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                        Button { selected = index; invalid = false } label: {
                            Circle().fill(RGBPalette.color(color)).frame(width: 24, height: 24)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.2)))
                                .padding(3).overlay(Circle().strokeBorder(selected == index ? Color.accentColor : .clear, lineWidth: 2))
                        }.buttonStyle(.plain).accessibilityLabel("Colore \(index + 1): \(color)")
                            .accessibilityAddTraits(selected == index ? .isSelected : [])
                    }
                }
                HStack {
                    Button { mouse.spectrumColors?.append("#30D158"); selected = colors.count - 1; invalid = false } label: {
                        Image(systemName: "plus")
                    }.disabled(colors.count >= 8).accessibilityLabel("Aggiungi colore al gradiente")
                    Button { mouse.spectrumColors?.remove(at: selected); selected = min(selected, colors.count - 1); invalid = false } label: {
                        Image(systemName: "minus")
                    }.disabled(colors.count <= 2).accessibilityLabel("Rimuovi colore selezionato")
                    Spacer()
                    Button { mouse.spectrumColors?.swapAt(selected, selected - 1); selected -= 1; invalid = false } label: {
                        Image(systemName: "arrow.left")
                    }.disabled(selected == 0).accessibilityLabel("Sposta colore prima")
                    Button { mouse.spectrumColors?.swapAt(selected, selected + 1); selected += 1; invalid = false } label: {
                        Image(systemName: "arrow.right")
                    }.disabled(selected >= colors.count - 1).accessibilityLabel("Sposta colore dopo")
                }
                RGBPalette(title: "Colore \(selected + 1)", hex: selectedColor, invalid: $invalid).id("\(selected)-\(colors.count)")
                VStack(spacing: 5) {
                    HStack {
                        Text("Durata del ciclo")
                        Spacer()
                        Text("\(Int(mouse.spectrumDurationSeconds ?? 12)) s").monospacedDigit().foregroundStyle(.secondary)
                    }.font(.callout)
                    Slider(value: Binding(get: { mouse.spectrumDurationSeconds ?? 12 }, set: { mouse.spectrumDurationSeconds = $0 }), in: 2...120, step: 1)
                        .accessibilityLabel("Durata del ciclo in secondi")
                }
                if let gradient = try? RGBGradient(colors: colors, duration: mouse.spectrumDurationSeconds ?? 12) {
                    TimelineView(.animation(minimumInterval: 0.15, paused: reduceMotion)) { timeline in
                        HStack(spacing: 8) {
                            Circle().fill(RGBPalette.color(gradient.color(at: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate).hex)).frame(width: 15, height: 15)
                            Text("Anteprima del ciclo").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Sfuma tra i colori nell’ordine scelto e torna al primo. Il ciclo è gestito da PeripheralKit: lascia l’app aperta.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Il mouse gestisce il ciclo completo dei colori nel firmware.").font(.callout).foregroundStyle(.secondary)
            }
        }.onDisappear { invalid = false }
    }
}
