import SwiftUI

extension KeyboardConfiguration.Mode {
    var title: String {
        switch self {
        case .static: "Colore fisso"
        case .rainbow: "Arcobaleno"
        case .breathing: "Respiro"
        case .stream: "Scorrimento"
        case .radar: "Radar"
        case .reactive: "Dissolvenza reattiva"
        }
    }

    var icon: String {
        switch self {
        case .static: "sun.max"
        case .rainbow: "rainbow"
        case .breathing: "waveform.path"
        case .stream: "arrow.right"
        case .radar: "dot.radiowaves.left.and.right"
        case .reactive: "sparkles"
        }
    }
}

extension KeyboardConfiguration.Direction {
    var title: String {
        switch self {
        case .forward: "Avanti"
        case .reverse: "Indietro"
        }
    }
}

extension MouseConfiguration.Mode {
    var title: String {
        switch self {
        case .spectrum: "Ciclo colori"
        case .static: "Colore fisso"
        case .breathing: "Respiro"
        }
    }

    var icon: String {
        switch self {
        case .spectrum: "rainbow"
        case .static: "sun.max"
        case .breathing: "waveform.path"
        }
    }
}

struct RGBStudioView: View {
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
        lights = model.lights
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
    private var color: Binding<String> { keyboard ? $draft.keyboard.color : editedMouse.color }
    private var usesColor: Bool {
        keyboard ? draft.keyboard.mode.usesPrimaryColor : editedMouse.wrappedValue.mode.usesPrimaryColor
    }
    private var invalidConfiguration: Bool {
        (usesColor && invalidPrimary) ||
        (keyboard && draft.keyboard.mode.usesSecondaryColor && invalidSecondary) ||
        (!keyboard && editedMouse.wrappedValue.customSpectrum && invalidGradient)
    }

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
                        Group {
                            if keyboard { RGBDevicePreview(keyboard: draft.keyboard) }
                            else { RGBDevicePreview(mouse: draft.mouse) }
                        }
                        .frame(height: keyboard ? 150 : 180)
                        HStack(alignment: .top, spacing: 24) {
                            effects.frame(width: 165)
                            VStack(alignment: .leading, spacing: 18) {
                                Text("PERSONALIZZA").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                if !keyboard && editedMouse.wrappedValue.mode == .spectrum {
                                    RGBGradientEditor(mouse: editedMouse, invalid: $invalidGradient).id(paletteReset)
                                } else if usesColor {
                                    RGBPalette(title: "Colore", hex: color, invalid: $invalidPrimary).id("\(device)-\(paletteReset)")
                                } else {
                                    Text("Questo effetto gestisce automaticamente i colori.")
                                        .font(.callout).foregroundStyle(.secondary)
                                }
                                if keyboard {
                                    percentageSlider("Luminosità", value: $draft.keyboard.brightness)
                                    if draft.keyboard.mode.supportsSpeed {
                                        percentageSlider("Velocità", value: $draft.keyboard.speed)
                                    }
                                    if draft.keyboard.mode.usesSecondaryColor {
                                        RGBPalette(title: "Secondo colore", hex: $draft.keyboard.secondaryColor, invalid: $invalidSecondary).id(paletteReset)
                                    }
                                    if draft.keyboard.mode.supportsDirection {
                                        Picker("Direzione", selection: $draft.keyboard.direction) {
                                            ForEach(KeyboardConfiguration.Direction.allCases, id: \.self) { direction in
                                                Text(direction.title).tag(direction)
                                            }
                                        }.pickerStyle(.segmented)
                                    }
                                }
                                Toggle("Includi nello stop e nel ripristino", isOn: included).font(.callout)
                                Text(keyboard ? "Anteprima del profilo globale. Il layout identifica già ogni tasto; l’invio di colori individuali richiede ancora la verifica del protocollo hardware." : "L’anteprima è indicativa e non legge i LED. Disattivando le zone separate, entrambe seguono la rotella.")
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
            appliedDevice = nil
            invalidPrimary = false
            invalidSecondary = false
            invalidGradient = false
        }
    }

    private var connected: Bool {
        model.devices.contains(where: device.matches)
    }

    private var effects: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("EFFETTI").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.bottom, 6)
            if keyboard {
                ForEach(KeyboardConfiguration.Mode.allCases, id: \.self) { mode in
                    effectButton(mode.title, icon: mode.icon, selected: draft.keyboard.mode == mode) { draft.keyboard.mode = mode }
                }
            } else {
                ForEach(MouseConfiguration.Mode.allCases, id: \.self) { mode in
                    effectButton(mode.title, icon: mode.icon, selected: editedMouse.wrappedValue.mode == mode) { editedMouse.wrappedValue.mode = mode }
                }
            }
        }
    }

    private func effectButton(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 20)
                Text(title).font(.callout)
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark").font(.caption.weight(.semibold)) }
            }.padding(.horizontal, 10).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
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
                    .disabled(model.rgbApplying || model.rgbSleeping || !model.hidGranted || invalidConfiguration)
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
        guard live, !invalidConfiguration else { return }
        let value = draft
        let target = device
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
        Binding(get: { .rgb(hex) }, set: { color in
            guard let value = color.rgbHex else { return }
            hex = value
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ColorPicker(title, selection: selection, supportsOpacity: false)
            HStack(spacing: 7) {
                ForEach(colors, id: \.self) { value in
                    Button { hex = value } label: {
                        Circle().fill(Color.rgb(value)).frame(width: 20, height: 20)
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
                        if rgb.hex != hex { hex = rgb.hex }
                    }.accessibilityLabel("\(title), valore esadecimale")
            }
            if invalid { Text("Inserisci sei cifre esadecimali, ad esempio #FF00FF.").font(.caption).foregroundStyle(.red) }
        }
        .onAppear { text = hex; invalid = false }
        .onDisappear { invalid = false }
        .onChange(of: hex) { _, value in text = value; invalid = false }
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
                    .fill(LinearGradient(colors: (colors + Array(colors.prefix(1))).map(Color.rgb), startPoint: .leading, endPoint: .trailing))
                    .frame(height: 22).accessibilityLabel("Gradiente ciclico di \(colors.count) colori")
                HStack(spacing: 6) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                        Button { selected = index; invalid = false } label: {
                            Circle().fill(Color.rgb(color)).frame(width: 24, height: 24)
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
                            Circle().fill(Color.rgb(gradient.color(at: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate).hex)).frame(width: 15, height: 15)
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
