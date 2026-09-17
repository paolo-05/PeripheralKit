# PeripheralKit

PeripheralKit is a native macOS 14+ menu-bar utility for remapping extra mouse
buttons and controlling the lighting of a Drevo Tyrfing V2 keyboard, a Razer
DeathAdder V2 mouse, and compatible HappyLighting/Triones LED strips.

It is intentionally local: there is no account, network service, analytics,
kernel extension, or cloud dependency.

## Features

- Map extra mouse buttons to the previous or next Space, Mission Control, or a
  custom keyboard shortcut.
- Apply mappings globally or only while a selected application is active.
- Consume or pass through the original mouse event.
- Control supported Drevo and Razer lighting profiles directly through IOKit.
- Configure Razer scroll-wheel and logo zones independently.
- Run a custom 2–8 color software gradient on the mouse.
- Save RGB scenes and restore profiles after sleep or USB reconnection.
- Control a compatible HappyLighting/Triones desk strip over CoreBluetooth.
- Start at login through `SMAppService`.
- Inspect a bounded in-memory diagnostic log and connected HID inventory.

## Supported hardware

| Device | Identifier | Support |
| --- | --- | --- |
| Drevo Tyrfing V2 | `0416:a0f8` | Static, rainbow, breathing, stream, radar, memory, brightness, speed, direction |
| Razer DeathAdder V2 | `1532:0084` | Spectrum, static, breathing, separate wheel/logo zones, software gradient |
| HappyLighting/Triones-compatible strip | Bluetooth UUID selected by the user | Power and RGB color for controllers using the documented packet format |

Hardware sold under the same consumer name may use a different protocol.
PeripheralKit refuses ambiguous Bluetooth characteristics, but unsupported
commands can still behave unpredictably. Use the application only with hardware
you are prepared to test.

## Requirements

- macOS 14 or later
- Xcode with Swift 6 support
- Accessibility permission for posting mapped shortcuts
- Input Monitoring permission for HID access
- Bluetooth permission when using a desk strip

PeripheralKit never grants these permissions automatically. macOS associates
privacy grants with the signed application identity and bundle path.

## Build and test

Open `PeripheralKit.xcodeproj`, select **My Mac**, and use the shared
`PeripheralKit` scheme:

| Xcode command | Result |
| --- | --- |
| Build (`⌘B`) | Builds the Debug app in DerivedData |
| Run (`⌘R`) | Runs the development app and opens its settings |
| Test (`⌘U`) | Runs XCTest without posting global input or touching the real configuration |
| Product → Archive | Creates a Release archive in Organizer |

The command-line equivalent used by CI is:

```sh
xcodebuild \
  -project PeripheralKit.xcodeproj \
  -scheme PeripheralKit \
  -destination 'platform=macOS' \
  test \
  CODE_SIGNING_ALLOWED=NO
```

`Package.swift` is retained for command-line tooling compatibility. The Xcode
project is the authoritative build, test, archive, and installation workflow.

## Local signing and installation

Portable defaults live in `Configuration/Defaults.xcconfig` and use ad-hoc
signing. This is enough to build, but macOS may treat successive ad-hoc builds
as different applications and request permissions again.

For a persistent identity:

```sh
cp Configuration/Local.xcconfig.example Configuration/Local.xcconfig
```

Edit the copied file with your own Apple Development, Developer ID, or local
code-signing identity. `Local.xcconfig` is ignored by Git and must never contain
exported certificates, private keys, or passwords.

The shared `PeripheralKit Install` scheme builds Release and copies the signed
app to `~/Applications/PeripheralKit.app` by default. Its Run action launches
the installed copy without a debugger. Close any running PeripheralKit copy
before switching schemes; the app prevents simultaneous instances.

The current application interface is in Italian. After the first install:

1. Open **Generali** and authorize Input Monitoring and Accessibility when
   requested.
2. Reopen the app if macOS asks you to do so.
3. Enable mouse remapping and, optionally, launch at login.

To uninstall, disable launch at login, quit PeripheralKit, and move the app to
the Trash. Settings remain at
`~/Library/Application Support/PeripheralKit/settings.json` until removed
manually.

## Mouse mappings

The default rules map button 4 to `Control–Left Arrow` and button 5 to
`Control–Right Arrow`. Enable those shortcuts in **System Settings → Keyboard →
Keyboard Shortcuts → Mission Control**, and create at least two Spaces.

Quartz does not expose a reliable public USB identity for the mouse that
generated an event. Mappings therefore apply to every connected mouse. The HID
inventory is diagnostic only and is not used to pretend that source-device
isolation exists.

Application-specific rules take precedence over global rules while preserving
their configured order. The event tap observes only extra mouse buttons; it
does not install a global keyboard-text monitor.

Use `--safe-mode` in the Xcode scheme arguments to suspend remapping and button
capture without changing saved preferences.

## USB lighting

The RGB editor keeps separate keyboard and mouse drafts. **Save and Apply**
persists and sends only the selected device profile; **Discard Changes** restores
the saved profile. A temporary hardware preview is debounced and is reverted
when it is cancelled, closed, or interrupted by sleep.

The custom mouse gradient is generated by PeripheralKit rather than uploaded to
the mouse firmware. It requires the menu-bar app to remain running. Three
consecutive USB failures stop the animation and produce a diagnostic entry.

Sleep and display-sleep automation are handled separately. After wake, each
device retries independently at bounded intervals. A successful USB write means
that the command was accepted by IOKit; it is not an optical measurement of the
LEDs. The pre-sleep power-off command is best effort because macOS can suspend
before an asynchronous device operation finishes.

## HappyLighting desk strips

Open **Luci scrivania**, scan for Bluetooth devices, and select the controller used
by HappyLighting. You can also enter the macOS Bluetooth UUID from an existing
configuration. The UUID is not a Bluetooth MAC address.

The implemented commands are:

- power: `CC 23/24 33`
- color: `56 R G B 19 F0 AA`

PeripheralKit records the last requested power state and color; it cannot read
the physical state or changes made by a phone. Wake restoration retries at most
three times and never turns on a strip that was manually left off.

## Data and privacy

- Settings are stored locally in Application Support.
- No configuration, device information, or diagnostics leave the Mac.
- No telemetry or network client is present.
- Diagnostic entries are bounded to 300 in memory. Selected lifecycle events
  also enter the local unified log with dynamic content marked private.
- The app observes extra mouse-button events and the active application's bundle
  identifier. It does not record typed text.

Do not attach an unredacted `settings.json`, Bluetooth UUID, HID serial number,
or unified-log export to a public issue.

## Documentation

- [Architecture](ARCHITECTURE.md)
- [Initial implementation scope](MVP.md)
- [Hardware and test verification record](VERIFICATION.md)
- [Product definition](PRODUCT.md)
- [Design direction](DESIGN.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

## Status and limitations

PeripheralKit is a personal utility with narrow, physically tested hardware
support. It is not notarized and there are no supported binary releases yet.
Device-source isolation, arbitrary per-key editing, generic HID plugins, and a
reliable readback of external LED state are not implemented.

See `VERIFICATION.md` for the distinction between automated coverage and tests
performed on physical hardware.

## License

PeripheralKit is available under the [MIT License](LICENSE). Protocol research
sources and their licenses are documented in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). PeripheralKit is not affiliated
with Apple, Drevo, Razer, or the HappyLighting vendors.
