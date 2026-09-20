import SwiftUI

struct RGBDevicePreview: View {
    private let keyboard: KeyboardConfiguration?
    private let mouse: MouseConfiguration?

    init(keyboard: KeyboardConfiguration) {
        self.keyboard = keyboard
        mouse = nil
    }

    init(mouse: MouseConfiguration) {
        keyboard = nil
        self.mouse = mouse
    }

    var body: some View {
        Group {
            if let keyboard { KeyboardPreview(configuration: keyboard) }
            else if let mouse { MousePreview(configuration: mouse) }
        }
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Anteprima indicativa \(keyboard == nil ? "mouse" : "tastiera")")
        .accessibilityElement(children: .ignore)
    }
}

private struct KeyboardPreview: View {
    let configuration: KeyboardConfiguration

    var body: some View {
        GeometryReader { geometry in
            let inset = 10.0
            let unit = min((geometry.size.width - inset * 2) / DrevoTKLLayout.width,
                           (geometry.size.height - inset * 2) / DrevoTKLLayout.height)
            let layoutWidth = DrevoTKLLayout.width * unit
            let layoutHeight = DrevoTKLLayout.height * unit
            let originX = (geometry.size.width - layoutWidth) / 2
            let originY = (geometry.size.height - layoutHeight) / 2
            let gap = max(1.5, unit * 0.13)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: layoutWidth + 14, height: layoutHeight + 14)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ForEach(DrevoTKLLayout.keys, id: \.id) { key in
                    let width = max(1, key.width * unit - gap)
                    let height = max(1, key.height * unit - gap)
                    let tint = tint(for: key)
                    let centerX = originX + (key.x + key.width / 2) * unit
                    let centerY = originY + (key.y + key.height / 2) * unit

                    RoundedRectangle(cornerRadius: max(2, unit * 0.15))
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: max(2, unit * 0.15))
                                .strokeBorder(tint.opacity(0.75), lineWidth: 1)
                        }
                        .shadow(color: tint.opacity(0.16), radius: 2)
                        .frame(width: width, height: height)
                        .overlay {
                            if !key.legend.isEmpty {
                                Text(key.legend)
                                    .font(.system(size: max(5.5, min(unit * 0.36, 9)), weight: .medium, design: .rounded))
                                    .foregroundStyle(tint)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                                    .padding(.horizontal, 2)
                            }
                        }
                        .position(x: centerX, y: centerY)
                }
            }
        }
    }

    private func tint(for key: DrevoKeyDescriptor) -> Color {
        let brightness = max(0, min(1, Double(configuration.brightness) / 100))
        if configuration.mode.usesAutomaticColors {
            let progress = max(0, min(1, (key.x + key.width / 2) / DrevoTKLLayout.width))
            return Color(hue: progress * 0.82, saturation: 0.78, brightness: 1).opacity(brightness)
        }
        return Color.rgb(configuration.color).opacity(brightness)
    }
}

private struct MousePreview: View {
    let configuration: MouseConfiguration

    var body: some View {
        Canvas { context, size in
            let width = 100.0
            let height = min(size.height - 16, 172)
            let x = (size.width - width) / 2
            let y = (size.height - height) / 2
            let body = Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: 44)
            context.fill(body, with: .color(Color(nsColor: .controlBackgroundColor)))
            context.stroke(body, with: .color(Color.primary.opacity(0.18)), lineWidth: 1)

            var seam = Path()
            seam.move(to: CGPoint(x: x + width / 2, y: y + 8))
            seam.addLine(to: CGPoint(x: x + width / 2, y: y + height * 0.43))
            context.stroke(seam, with: .color(Color.primary.opacity(0.15)), lineWidth: 1)

            let wheelTint = zoneColor(configuration.primary)
            let logoTint = zoneColor(configuration.logo ?? configuration.primary)
            context.fill(Path(roundedRect: CGRect(x: x + 44, y: y + 23, width: 12, height: 30), cornerRadius: 5), with: .color(wheelTint))
            context.draw(Text("R").font(.system(size: 26, weight: .medium, design: .rounded)).foregroundColor(logoTint),
                         at: CGPoint(x: x + width / 2, y: y + height * 0.72))
            context.draw(Text("Rotella").font(.caption).foregroundColor(.secondary),
                         at: CGPoint(x: x + width + 42, y: y + 38))
            context.draw(Text("Logo").font(.caption).foregroundColor(.secondary),
                         at: CGPoint(x: x + width + 42, y: y + height * 0.72))
        }
    }

    private func zoneColor(_ profile: MouseZoneConfiguration) -> Color {
        if profile.mode == .spectrum { return profile.spectrumColors?.first.map(Color.rgb) ?? .green }
        return Color.rgb(profile.color)
    }
}
