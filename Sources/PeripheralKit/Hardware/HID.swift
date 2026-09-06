import Foundation
import IOKit
import IOKit.hid

struct HIDDescriptor {
    let device: IOHIDDevice
    let product: String
    let vendorID: Int
    let productID: Int
    let usagePage: Int
    let usage: Int
    let maxFeatureReportSize: Int
    let maxOutputReportSize: Int
    let locationID: Int
}

final class HIDSession {
    private var manager: IOHIDManager?
    private(set) var descriptors: [HIDDescriptor] = []

    func discover(vendorID: Int, productID: Int) throws -> [HIDDescriptor] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDProductIDKey: productID,
        ] as CFDictionary)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            if openResult == kIOReturnNotPermitted {
                throw PeripheralKitError.permissionDenied
            }
            throw PeripheralKitError.deviceOpenFailed("HID Manager", openResult)
        }

        self.manager = manager
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        descriptors = devices.map(Self.describe)
        return descriptors
    }

    func open(_ descriptor: HIDDescriptor, named name: String) throws -> IOHIDDevice {
        let result = IOHIDDeviceOpen(descriptor.device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw PeripheralKitError.deviceOpenFailed(name, result)
        }
        return descriptor.device
    }

    func close(_ device: IOHIDDevice) {
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit {
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    private static func integer(_ device: IOHIDDevice, _ key: CFString) -> Int {
        if let number = IOHIDDeviceGetProperty(device, key) as? NSNumber {
            return number.intValue
        }
        return 0
    }

    private static func describe(_ device: IOHIDDevice) -> HIDDescriptor {
        HIDDescriptor(
            device: device,
            product: (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? "Sconosciuto",
            vendorID: integer(device, kIOHIDVendorIDKey as CFString),
            productID: integer(device, kIOHIDProductIDKey as CFString),
            usagePage: integer(device, kIOHIDPrimaryUsagePageKey as CFString),
            usage: integer(device, kIOHIDPrimaryUsageKey as CFString),
            maxFeatureReportSize: integer(device, kIOHIDMaxFeatureReportSizeKey as CFString),
            maxOutputReportSize: integer(device, kIOHIDMaxOutputReportSizeKey as CFString),
            locationID: integer(device, kIOHIDLocationIDKey as CFString)
        )
    }
}

func requestHIDAccessIfNeeded() throws {
    let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    if access == kIOHIDAccessTypeUnknown {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    } else if access == kIOHIDAccessTypeDenied {
        throw PeripheralKitError.permissionDenied
    }
}

func hidAccessDescription() -> String {
    switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
    case kIOHIDAccessTypeGranted: return "autorizzato"
    case kIOHIDAccessTypeDenied: return "negato"
    default: return "non ancora deciso"
    }
}
