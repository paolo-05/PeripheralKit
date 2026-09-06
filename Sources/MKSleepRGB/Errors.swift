import Foundation
import IOKit

enum MKSleepError: LocalizedError {
    case deviceNotFound(String)
    case deviceOpenFailed(String, IOReturn)
    case reportFailed(String, IOReturn)
    case permissionDenied
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let name):
            return "Dispositivo non trovato: \(name)"
        case .deviceOpenFailed(let name, let code):
            return "Impossibile aprire \(name) (IOKit 0x\(String(UInt32(bitPattern: code), radix: 16)))."
        case .reportFailed(let name, let code):
            return "Scrittura HID fallita su \(name) (IOKit 0x\(String(UInt32(bitPattern: code), radix: 16)))."
        case .permissionDenied:
            return "Accesso HID negato. Abilita mksleep-rgb in Impostazioni di Sistema > Privacy e sicurezza > Monitoraggio input."
        case .invalidConfiguration(let message):
            return message
        }
    }
}
