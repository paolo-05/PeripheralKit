# PeripheralKit verification record

This file distinguishes automated coverage from observations made with physical
hardware. A successful IOKit or GATT write confirms transport completion, not
the optical state of an LED.

## Current automated verification

The public-repository preparation fixed the Xcode test target so that it uses
the production types compiled directly into `PeripheralKitTests`. The canonical
command is the same command used by `.github/workflows/ci.yml`:

```sh
xcodebuild \
  -project PeripheralKit.xcodeproj \
  -scheme PeripheralKit \
  -destination 'platform=macOS' \
  test \
  CODE_SIGNING_ALLOWED=NO
```

The tests use in-memory Quartz event collectors and mocked USB/Bluetooth
transports. They do not post global input, access the real settings file, or
require connected hardware.

On September 17, 2026, the command completed with **61 passed tests, 0 failures,
and 0 skipped tests** on arm64 macOS. The application also built successfully
with code signing disabled. A redundant, unassigned 1024×1024 icon that duplicated
the assigned 512@2x asset was removed from the catalog.

The SwiftPM compatibility path was verified separately with `swift test`: the
same 61 XCTest cases passed with no failures.

## Scenes, zones, and reconnection — September 13, 2026

- A five-color Razer gradient was physically confirmed as smooth on both zones.
  Full sleep and wake restored keyboard, mouse, desk strip, and software cycle.
- A newly installed Release retained permissions. After dock disconnect and
  reconnect, USB profiles and the gradient returned automatically; side-button
  Space switching was confirmed.
- Hardware preview was confirmed with a static red logo and wheel gradient. The
  saved JSON stayed unchanged, and cancelling restored the saved two-zone
  gradient.
- A “Desk” scene applied the saved USB profiles and desk-strip state. USB logs
  and the controller's Bluetooth acknowledgement were observed.
- The native application picker was tested with an Automator-specific rule and
  then restored to All Applications. Precedence and fallback were also covered
  without emitting synthetic input to other apps.
- The suite at that milestone contained 61 passing XCTest cases, including
  transient reconnection, no wake during sleep, scene/zone compatibility, and
  per-zone interpolation.
- A real logout/login cycle and multi-hour endurance run were not performed.

## Per-device editor and custom gradient — September 9, 2026

- The editor was reorganized around keyboard/mouse selection, schematic preview,
  effect list, palette/HEX controls, sliders, and persistent Save/Discard actions.
- Independent drafts, invalid-HEX blocking, cancellation, and targeted device
  application were verified. Applying a device excluded from sleep automation
  remained supported without cancelling the other device's pending restore.
- Full Spectrum and a 2–8 color custom gradient were added. The software gradient
  requires the application to remain open; the firmware Spectrum command remains
  unchanged when no palette exists.
- The milestone suite contained 54 passing XCTest cases covering cyclic
  interpolation, validation, persistence, USB error limits, sleep cancellation,
  and replacement by a fixed color.
- The installed UI was checked, but the final physical gradient run was deferred
  because neither supported HID interface was connected in that session.

## RGB editor — September 9, 2026

- Native selectors were added for every supported Drevo/Razer effect, including
  conditional color controls, Drevo brightness, and animation parameters.
- The milestone suite contained 47 passing tests. New regressions covered manual
  application taking precedence over wake retries, refusal during sleep, and
  partial results when a device is excluded.
- Release build, native-scheme installation, signing, and retained permissions
  succeeded.
- The installed UI switched the mouse between Spectrum and Static and reported
  successful writes to both devices. The original profiles were restored.
- Transport writes were verified; every visual effect was not individually
  confirmed by the user.

## Hardware session — September 8, 2026

- The Xcode baseline contained 34 passing tests.
- Accessibility and Input Monitoring were authorized. Launch at login was
  registered but a real logout/login was not performed.
- The real HID inventory found two Drevo interfaces and four Razer interfaces.
  The Drevo RGB endpoint was accessible and Razer firmware reported 2.0.
- A two-second CLI off/on cycle succeeded on both USB devices and was visually
  confirmed.
- A Triones strip powered off and returned to magenta. One connection attempt
  timed out; the next received a GATT acknowledgement, demonstrating that
  transient Bluetooth errors remain possible.
- During a full sleep/wake cycle, the user confirmed keyboard and mouse restore.
  Razer restored first; Drevo recovered on its seventh bounded attempt and
  completed its additional sends.
- Dock disconnect/reconnect, side buttons, and Space switching were physically
  confirmed.
- With the strip unpowered, timeout was visible and the UI remained responsive.
  After power returned, connection and color were acknowledged again.
- BLE automation tests brought the suite to 44 cases, covering JSON compatibility,
  requested-state persistence, overlapping display/system sleep, bounded retry,
  manual cancellation, disabling/removal, new sleep, and disabled restoration.
- A later full sleep powered the strip off before suspension and restored it
  after wake. The user confirmed all lights off during sleep and restored after
  wake. A manually powered-off strip correctly stayed off through another cycle.
- A display-only sleep produced one Bluetooth timeout, then an automatic retry
  succeeded. The user confirmed all lights off and restored.

### Limits of the September 8 session

Bluetooth permission revocation, Bluetooth being unavailable for an entire
automatic restore, and a real logout/login were not tested. Simulated tests cover
bounded retries and cancellation, but one successful sleep cycle does not prove
that macOS will always leave enough time for a Bluetooth write.

## Space-switching correction

- Synthetic events were moved to the HID event tap, before session shortcut
  processing.
- Event-posting permission is checked and failure is explicit.
- The UI exposes both directions and diagnostics distinguish “shortcut sent”
  from the independent `spaceChanged` notification.
- Regression tests cover the HID destination, complete key pairs, modifier order,
  denied posting, and preservation of RGB configuration.
- Quartz tests collect events in memory and never publish global input.

The milestone suite contained 29 passing tests after obsolete migration tests
were removed and the posting regressions were added. Release build, installation,
archive, bundle signing, and the installed UI were checked. macOS required the
user to reauthorize permissions after the signing transition.

## Persistent signing and keyboard restore — September 7, 2026

- A persistent local certificate was created in the login keychain with explicit
  user consent. No certificate or key entered the repository.
- Debug and Release had different CDHashes but the same designated requirement
  based on bundle identifier and leaf certificate.
- The milestone suite contained 32 passing tests, including recovery after five
  initial failures, Drevo sends independent from the mouse, and cancellation by
  a new sleep.
- Drevo reopened HID and resent the profile twice after first success. Each stage
  had at most seven attempts.
- Replacing an authorized Debug build with Release preserved both Accessibility
  and Input Monitoring grants.
- In a physical run, four Drevo IOKit failures were followed by recovery; Razer
  restored independently. The user confirmed that the keyboard lit again.

## HappyLighting BLE — September 7, 2026

- Native CoreBluetooth discovery, selection, persistent color, power control,
  and menu-bar actions were added.
- The milestone suite contained 34 passing tests, including packet bytes checked
  against the previously working Python script and optional-configuration
  compatibility.
- The Xcode Debug target built with the local identity.
- The initial sandboxed run could not create Quartz events for three existing
  tests; outside the sandbox, the entire suite passed.
- No physical BLE test had yet been performed at this milestone; those checks
  were completed in the September 8 session above.

## Remaining physical checks

- A real logout/login launch test.
- Long-duration custom-gradient operation and repeated sleep cycles.
- Bluetooth permission revocation and recovery.
- Additional firmware revisions and controllers sold under the same product
  names.
