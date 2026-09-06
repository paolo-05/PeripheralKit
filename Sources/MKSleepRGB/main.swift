import AppKit
import Foundation

private struct Arguments {
    let command: String
    let configPath: String?

    init(_ values: [String]) throws {
        var values = Array(values.dropFirst())
        command = values.first ?? "help"
        if !values.isEmpty { values.removeFirst() }

        var path: String?
        while !values.isEmpty {
            let flag = values.removeFirst()
            guard flag == "--config", let value = values.first else {
                throw MKSleepError.invalidConfiguration("Argomento sconosciuto o incompleto: \(flag)")
            }
            path = value
            values.removeFirst()
        }
        configPath = path
    }
}

private func printHelp() {
    print("""
    mksleep-rgb — spegne gli RGB USB durante lo stop del Mac

    Uso:
      mksleep-rgb devices
      mksleep-rgb check
      mksleep-rgb authorize
      mksleep-rgb off [--config file.json]
      mksleep-rgb on [--config file.json]
      mksleep-rgb test [--config file.json]
      mksleep-rgb daemon [--config file.json]

    devices  Elenca le interfacce HID compatibili senza scrivere nulla
    check    Apre i dispositivi e legge la versione firmware del mouse
    authorize Richiede a macOS il permesso Monitoraggio input
    off/on   Spegne o ripristina l'illuminazione
    test     Esegue un ciclo spento/acceso di due secondi
    daemon   Resta in ascolto di stop e riattivazione
    """)
}

private func printDevices() throws {
    let targets = [
        ("Drevo Tyrfing V2", DrevoTyrfingV2.vendorID, DrevoTyrfingV2.productID),
        ("Razer DeathAdder V2", RazerDeathAdderV2.vendorID, RazerDeathAdderV2.productID),
    ]
    for (name, vendor, product) in targets {
        let session = HIDSession()
        let matches = try session.discover(vendorID: vendor, productID: product)
        print("\(name): \(matches.count) interfacce HID")
        for item in matches.sorted(by: { ($0.usagePage, $0.usage) < ($1.usagePage, $1.usage) }) {
            print("  usage=0x\(String(item.usagePage, radix: 16)):0x\(String(item.usage, radix: 16)) feature=\(item.maxFeatureReportSize) output=\(item.maxOutputReportSize) location=0x\(String(item.locationID, radix: 16))")
        }
    }
}

private func checkDevices() throws {
    try requestHIDAccessIfNeeded()
    let keyboard = DrevoTyrfingV2()
    try keyboard.connect()
    keyboard.disconnect()
    print("Drevo Tyrfing V2: interfaccia RGB accessibile")

    let mouse = RazerDeathAdderV2()
    try mouse.connect()
    let firmware = try mouse.firmwareVersion()
    mouse.disconnect()
    print("Razer DeathAdder V2: firmware \(firmware)")
}

@MainActor
private func authorizeHID() throws {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)

    if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted {
        print("Monitoraggio input: già autorizzato")
        return
    }

    _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    let deadline = Date().addingTimeInterval(90)
    while Date() < deadline {
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted {
            print("Monitoraggio input: autorizzato")
            return
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
    }
    throw MKSleepError.permissionDenied
}

private func printResult(_ result: ApplyResult, state: PowerState) -> Int32 {
    for device in result.successes { print("\(device): RGB \(state == .sleeping ? "spenti" : "ripristinati")") }
    for failure in result.failures { Log.error(failure) }
    return result.succeeded ? 0 : 1
}

do {
    let arguments = try Arguments(CommandLine.arguments)
    if ["help", "--help", "-h"].contains(arguments.command) {
        printHelp()
        exit(0)
    }

    if arguments.command == "devices" {
        try printDevices()
        exit(0)
    }
    if arguments.command == "check" {
        try checkDevices()
        exit(0)
    }
    if arguments.command == "authorize" {
        try authorizeHID()
        try checkDevices()
        exit(0)
    }

    guard ["off", "on", "test", "daemon"].contains(arguments.command) else {
        printHelp()
        throw MKSleepError.invalidConfiguration("Comando sconosciuto: \(arguments.command)")
    }

    try requestHIDAccessIfNeeded()
    let configuration = try Configuration.load(from: arguments.configPath)
    let controller = RGBController(configuration: configuration)

    switch arguments.command {
    case "off":
        exit(printResult(controller.apply(.sleeping), state: .sleeping))
    case "on":
        exit(printResult(controller.apply(.awake), state: .awake))
    case "test":
        let off = controller.apply(.sleeping)
        let offStatus = printResult(off, state: .sleeping)
        guard offStatus == 0 else { exit(offStatus) }
        Thread.sleep(forTimeInterval: 2)
        exit(printResult(controller.apply(.awake), state: .awake))
    case "daemon":
        let watcher = SleepWatcher(controller: controller)
        watcher.run()
    default:
        fatalError("Comando già validato")
    }
} catch {
    Log.error(error.localizedDescription)
    exit(1)
}
