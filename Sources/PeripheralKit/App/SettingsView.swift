import SwiftUI

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "Generali", mouse = "Mouse", devices = "Dispositivi", rgb = "RGB e stop", diagnostics = "Diagnostica", about = "Informazioni"
    var id: String { rawValue }
    var icon: String {
        switch self {
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
                Text("Le mappature sono globali e si applicano a tutti i mouse. Puoi sospenderle subito dal menu nella barra di stato.")
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
            Section {
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

    private var rgb: some View {
        Form {
            Section {
                Toggle("Abilita automazione RGB", isOn: $model.configuration.rgbEnabled)
                Toggle("Spegni quando il Mac va in stop", isOn: $model.configuration.systemSleepEnabled)
                Toggle("Spegni quando gli schermi si spengono", isOn: $model.configuration.displaySleepEnabled)
                Toggle("Ripristina al risveglio", isOn: $model.configuration.restoreOnWake)
                Stepper(value: $model.configuration.rgb.wakeDelaySeconds, in: 0...30, step: 0.25) {
                    LabeledContent("Attesa dopo il risveglio", value: String(format: "%.2f s", model.configuration.rgb.wakeDelaySeconds))
                }
            } header: { Text("Comportamento") }
            Section("Periferiche") {
                Toggle("Drevo Tyrfing V2", isOn: $model.configuration.rgb.keyboard.enabled)
                LabeledContent("Profilo tastiera", value: model.configuration.rgb.keyboard.mode.rawValue)
                Toggle("Razer DeathAdder V2", isOn: $model.configuration.rgb.mouse.enabled)
                LabeledContent("Profilo mouse", value: model.configuration.rgb.mouse.mode.rawValue)
                Text("Al risveglio viene riapplicato il profilo configurato. Gli effetti modificati da altre app non possono essere letti in modo affidabile.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Mostra configurazione nel Finder") { NSWorkspace.shared.selectFile(model.store.url.path, inFileViewerRootedAtPath: model.store.directory.path) }
                Text("Il profilo RGB precedente viene importato da MKSleepRGB al primo avvio. Per modificare colori ed effetti, chiudi l'app e modifica la sezione rgb del JSON.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var about: some View {
        Form {
            Section {
                Label("PeripheralKit", systemImage: "computermouse.fill").font(.title2.bold())
                Text("Periferiche e piccole automazioni per macOS.")
                Text("Versione 0.1 · macOS 14 o successivo").foregroundStyle(.secondary)
            }
            Section {
                Text("Controllo RGB diretto per Drevo Tyrfing V2 e Razer DeathAdder V2. Nessun driver kernel, analytics o servizio di rete.")
                Text("Prima versione: rimappature globali. Profili per applicazione, isolamento del mouse e integrazione OpenRGB sono previsti nei prossimi incrementi.").foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}

private struct MappingRow: View {
    @Binding var rule: Rule
    let delete: () -> Void
    private var button: Int { if case .mouseButton(let button) = rule.trigger { button } else { 0 } }
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
