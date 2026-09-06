import AppKit
import SwiftUI

@main
struct PeripheralKitMain {
    @MainActor static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let first = arguments.first, !["--safe-mode", "--settings"].contains(first), !first.hasPrefix("-psn_") {
            runCLI()
            return
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate(safeMode: arguments.contains("--safe-mode"))
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let model: AppModel
    private var statusItem: NSStatusItem?
    private var window: NSWindow?

    init(safeMode: Bool) { model = AppModel(safeMode: safeMode) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })?.activate()
            NSApp.terminate(nil)
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "PeripheralKit")
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
        model.startRefreshing()
        if !UserDefaults.standard.bool(forKey: "hasOpenedSettings") || CommandLine.arguments.contains("--settings") || model.safeMode { showSettings() }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: model.safeMode ? "PeripheralKit · Modalità sicura" : "PeripheralKit", action: nil, keyEquivalent: "")
        menu.addItem(title)
        menu.addItem(.separator())
        let remap = NSMenuItem(title: "Abilita rimappatura mouse", action: #selector(toggleRemapping), keyEquivalent: "")
        remap.target = self
        remap.state = model.configuration.remappingEnabled && !model.safeMode ? .on : .off
        remap.isEnabled = !model.safeMode
        menu.addItem(remap)
        let rgb = NSMenuItem(title: "Abilita automazione RGB", action: #selector(toggleRGB), keyEquivalent: "")
        rgb.target = self
        rgb.state = model.configuration.rgbEnabled ? .on : .off
        menu.addItem(rgb)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Impostazioni…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Esci da PeripheralKit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc func toggleRemapping() { model.configuration.remappingEnabled.toggle() }
    @objc func toggleRGB() { model.configuration.rgbEnabled.toggle() }
    @objc func showSettings() {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: controller)
            window.title = "PeripheralKit"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 850, height: 640))
            window.minSize = NSSize(width: 740, height: 540)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        UserDefaults.standard.set(true, forKey: "hasOpenedSettings")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
