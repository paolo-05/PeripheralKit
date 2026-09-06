import AppKit

// Xcode runs this tiny native launcher after the install target completes.
// It reads the resolved install path from the built app's Info.plist, avoiding
// shell expansion and user-specific absolute paths in shared schemes.
@main
struct LaunchInstalled {
    @MainActor static func main() async {
        do {
            let products = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
            let plistURL = products.appendingPathComponent("PeripheralKit.app/Contents/Info.plist")
            let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as? [String: Any]
            guard let directory = plist?["PeripheralKitInstallDirectory"] as? String,
                  directory.hasPrefix("/"), !directory.contains("$(") else {
                throw NSError(domain: "PeripheralKitLauncher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Destinazione di installazione non valida. Ricompila lo schema PeripheralKit Install."])
            }
            let application = URL(fileURLWithPath: directory).appendingPathComponent("PeripheralKit.app")
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = ["--settings"]
            _ = try await NSWorkspace.shared.openApplication(at: application, configuration: configuration)
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
