import CoreBluetooth
import Combine
import Foundation

@MainActor
protocol DeskLightTransport: AnyObject {
    func send(to id: UUID, on: Bool, color: RGBColor, completion: @escaping (Result<Void, Error>) -> Void)
    func cancel()
}

/// Packets used by RGB-remote/LED_source.py (HappyLighting/Triones).
enum HappyLightingPacket {
    static func power(_ on: Bool) -> Data { Data([0xCC, on ? 0x23 : 0x24, 0x33]) }
    static func color(_ color: RGBColor) -> Data {
        Data([0x56, color.red, color.green, color.blue, 25, 0xF0, 0xAA])
    }
}

@MainActor
final class HappyLighting: NSObject, ObservableObject, DeskLightTransport, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    struct Device: Identifiable { let id: UUID; let name: String }
    @Published private(set) var devices: [Device] = []
    @Published private(set) var busy = false
    @Published private(set) var status = "Cerca e seleziona la tua striscia HappyLighting."
    @Published private(set) var error: String?
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var target: UUID?
    private var packets: [Data] = []
    private var characteristic: CBCharacteristic?
    private var timeout: Task<Void, Never>?
    private var scanning = false
    private var started = false
    private var remainingServices = 0
    private var candidates: [CBCharacteristic] = []
    private var completion: ((Result<Void, Error>) -> Void)?

    func scan() {
        guard !busy else { return }
        devices = []; scanning = true; begin()
    }

    func send(to id: UUID, on: Bool, color: RGBColor, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !busy else {
            completion(.failure(PeripheralKitError.invalidConfiguration("Operazione Bluetooth già in corso.")))
            return
        }
        self.completion = completion
        target = id
        packets = [HappyLightingPacket.power(on)]
        if on { packets.append(HappyLightingPacket.color(color)) }
        scanning = false; begin()
    }

    private func begin() {
        busy = true; error = nil; started = false
        status = "Preparazione Bluetooth…"
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self else { return }
            if self.scanning { self.finish(self.devices.isEmpty ? "Nessuna striscia trovata. Avvicinala e riprova." : "Seleziona la striscia da controllare.") }
            else { self.fail("La striscia non risponde. Verifica alimentazione, distanza e chiudi HappyLighting sul telefono, poi riprova.") }
        }
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else { startIfReady() }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard busy else { return }
        startIfReady()
    }

    private func startIfReady() {
        guard let central else { return }
        switch central.state {
        case .poweredOn:
            guard !started else { return }; started = true
            if scanning { status = "Ricerca strisce Bluetooth…"; central.scanForPeripherals(withServices: nil) }
            else if let target, let known = central.retrievePeripherals(withIdentifiers: [target]).first { connect(known) }
            else { status = "Ricerca della striscia…"; central.scanForPeripherals(withServices: nil) }
        case .unauthorized: fail("Autorizza PeripheralKit in Impostazioni di Sistema → Privacy e sicurezza → Bluetooth.")
        case .poweredOff: fail("Bluetooth disattivato. Attivalo e riprova.")
        case .unsupported: fail("Bluetooth LE non disponibile su questo Mac.")
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard busy else { return }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Striscia BLE"
        if scanning {
            let lower = name.lowercased()
            guard lower.contains("triones") || lower.contains("happy") || lower.contains("elk") || lower.contains("led") else { return }
            if !devices.contains(where: { $0.id == peripheral.identifier }) { devices.append(Device(id: peripheral.identifier, name: name)) }
        } else if peripheral.identifier == target { connect(peripheral) }
    }

    private func connect(_ device: CBPeripheral) {
        central?.stopScan(); peripheral = device; device.delegate = self
        status = "Connessione alla striscia…"; central?.connect(device)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard busy, peripheral === self.peripheral else { return }
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard busy, peripheral === self.peripheral else { return }
        if let error { fail(error.localizedDescription); return }
        // The working Python implementation uses a vendor service, never GAP/GATT.
        let services = (peripheral.services ?? []).filter { !["1800", "1801"].contains($0.uuid.uuidString) }
        remainingServices = services.count; candidates = []
        guard !services.isEmpty else { fail("Nessun servizio HappyLighting compatibile."); return }
        for service in services { peripheral.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard busy, peripheral === self.peripheral else { return }
        if let error { fail(error.localizedDescription); return }
        candidates += (service.characteristics ?? []).filter { $0.properties.contains(.write) && $0.properties.contains(.writeWithoutResponse) }
        remainingServices -= 1
        guard remainingServices == 0 else { return }
        guard candidates.count == 1 else { fail("Servizio BLE non riconosciuto o ambiguo: nessun comando inviato."); return }
        characteristic = candidates[0]; writeNext()
    }

    private func writeNext() {
        guard let peripheral, let characteristic else { return }
        guard !packets.isEmpty else { finish("Comando inviato alla striscia."); return }
        status = "Invio comando…"
        peripheral.writeValue(packets.removeFirst(), for: characteristic, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard busy, peripheral === self.peripheral, characteristic === self.characteristic else { return }
        if let error { fail(error.localizedDescription) } else { writeNext() }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard busy, peripheral === self.peripheral else { return }
        fail(error?.localizedDescription ?? "Connessione alla striscia non riuscita.")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard busy, peripheral === self.peripheral else { return }
        fail(error?.localizedDescription ?? "Striscia scollegata prima del completamento.")
    }

    func cancel() {
        guard busy else { return }
        finish("Operazione annullata.", result: .failure(CancellationError()))
    }
    private func fail(_ message: String) {
        error = message
        finish("Operazione non riuscita.", result: .failure(PeripheralKitError.invalidConfiguration(message)))
    }
    private func finish(_ message: String, result: Result<Void, Error> = .success(())) {
        let callback = completion; completion = nil
        timeout?.cancel(); timeout = nil; busy = false; started = false
        central?.stopScan()
        let old = peripheral; peripheral = nil; old?.delegate = nil
        if let old { central?.cancelPeripheralConnection(old) }
        characteristic = nil; packets = []; candidates = []; target = nil
        status = message
        callback?(result)
    }
}
