import AppKit
import SwiftUI

@main
struct PeripheralKitMain {
    @MainActor static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if LaunchMode.resolve(arguments: arguments) == .commandLine {
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
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let model: AppModel
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var runtime: AppRuntime?

    init(safeMode: Bool) { model = AppModel(safeMode: safeMode) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })?.activate()
            NSApp.terminate(nil)
            return
        }
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "PeripheralKit")
        let preferences = NSMenuItem(title: "Impostazioni…", action: #selector(showSettings), keyEquivalent: ",")
        preferences.target = self
        appMenu.addItem(preferences)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Esci da PeripheralKit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "PeripheralKit")
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
        runtime = AppRuntime(model: model)
        runtime?.start()
        model.startRefreshing()
        if CommandLine.arguments.contains("--enable-login") { model.setLogin(true) }
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
        if model.configuration.deskLight != nil {
            for (title, action) in [("Accendi luci scrivania", #selector(deskLightsOn)), ("Spegni luci scrivania", #selector(deskLightsOff))] {
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.target = self
                item.isEnabled = !model.lights.busy
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem(title: model.lights.error ?? model.lights.status, action: nil, keyEquivalent: ""))
            menu.addItem(.separator())
        }
        if let scenes = model.configuration.scenes, !scenes.isEmpty {
            let item = NSMenuItem(title: "Scene RGB", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for scene in scenes {
                let entry = NSMenuItem(title: scene.name, action: #selector(applyScene(_:)), keyEquivalent: "")
                entry.target = self
                entry.representedObject = scene.id.uuidString
                entry.isEnabled = !model.rgbSleeping && !model.rgbApplying && !model.lights.busy
                submenu.addItem(entry)
            }
            item.submenu = submenu
            menu.addItem(item)
        }
        let settings = NSMenuItem(title: "Impostazioni…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Esci da PeripheralKit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc func applyScene(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let scene = model.configuration.scenes?.first(where: { $0.id.uuidString == id }) else { return }
        model.applyScene(scene)
    }
    @objc func deskLightsOn() { model.setDeskLight(on: true) }
    @objc func deskLightsOff() { model.setDeskLight(on: false) }
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
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        UserDefaults.standard.set(true, forKey: "hasOpenedSettings")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func windowWillClose(_ notification: Notification) { model.cancelRecording(); model.previewCancellation += 1; model.previewCancelRequested?() }
    func applicationWillTerminate(_ notification: Notification) { runtime?.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
