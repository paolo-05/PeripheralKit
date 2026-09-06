import Foundation
import IOKit
import IOKit.hid

protocol PeripheralProvider {
    func devices() throws -> [PeripheralDevice]
}

// Runs on a utility queue. Does not seize devices or install keyboard callbacks.
struct HIDDeviceManager: PeripheralProvider, Sendable {
    func devices() throws -> [PeripheralDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        IOHIDManagerSetDeviceMatching(manager, nil)
        // Enumeration alone does not require opening devices or prompting for access.
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        return devices.map { device in
            func int(_ key: String) -> Int { (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0 }
            func string(_ key: String) -> String? { IOHIDDeviceGetProperty(device, key as CFString) as? String }
            let vendor = int(kIOHIDVendorIDKey), product = int(kIOHIDProductIDKey)
            let location = int(kIOHIDLocationIDKey), page = int(kIOHIDPrimaryUsagePageKey), usage = int(kIOHIDPrimaryUsageKey)
            let serial = string(kIOHIDSerialNumberKey).flatMap { $0.isEmpty ? nil : $0 }
            var registry: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &registry)
            return PeripheralDevice(
                id: "\(vendor):\(product):\(serial ?? String(location)):\(page):\(usage):\(registry)",
                vendorID: vendor, productID: product, serialNumber: serial,
                productName: string(kIOHIDProductKey) ?? "Periferica HID", manufacturer: string(kIOHIDManufacturerKey) ?? "Non disponibile",
                locationID: location, usagePage: page, usage: usage
            )
        }.filter { $0.usagePage == 1 || $0.supportsRGB }.sorted { ($0.productName, $0.id) < ($1.productName, $1.id) }
    }
}
