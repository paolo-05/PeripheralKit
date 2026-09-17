# PeripheralKit architecture

PeripheralKit is a macOS 14+ Swift 6 application built with SwiftUI and AppKit.
It runs as a menu-bar accessory, has no network dependency, and keeps hardware
access behind narrow adapters that can be replaced in tests.

## System boundaries

| Subsystem | APIs | Permissions | Important limits |
| --- | --- | --- | --- |
| Application | SwiftUI, AppKit, `NSStatusItem`, `NSWindow` | None | `LSUIElement` accessory app with a menu-reopenable settings window |
| Mouse input | `CGEvent.tapCreate` session event tap | Accessibility | Observes only `otherMouseDown` and `otherMouseUp`; no typed text |
| Actions | Synthetic `CGEvent` keyboard events posted to the HID tap | Accessibility | Mission Control shortcuts must be enabled in macOS |
| HID inventory | `IOHIDManager`, `IOHIDDevice` properties | Input Monitoring | VID/PID plus serial, registry, or location identity is not a reliable mouse-event source |
| Rules | Codable models and a synchronous matcher | None | Application rules precede global rules; first match wins |
| Power events | `NSWorkspace` sleep/wake and display notifications | None | Pre-sleep USB/Bluetooth completion is best effort |
| USB RGB | Compiled adapters and `IOHIDDeviceSetReport` | Input Monitoring | Restores the configured profile; cannot observe arbitrary firmware state |
| Bluetooth | CoreBluetooth | Bluetooth | Supports a narrow HappyLighting/Triones command format; no physical-state readback |
| Login | `SMAppService.mainApp` | User approval may be required | Requires an installed app bundle |
| Persistence | Atomic JSON in Application Support | None | A corrupt file is reported and never silently replaced |
| Diagnostics | Unified logging and a bounded in-memory buffer | None | Dynamic unified-log content is private; no keystroke content |

The distributed app is not sandboxed because direct HID access and the active
event tap are core features. No private API or kernel driver is used.

## Event identity and rule evaluation

Quartz does not expose a reliable public USB identity for the mouse that created
an event. The HID list is therefore an inventory, not proof of event origin.
Mappings apply to all mice, and capture explicitly reports that the physical
source is unavailable. Correlating HID and Quartz timestamps would create false
confidence when multiple devices or simultaneous events are present.

The input path is:

```text
InputEventSource → RuleEngine → ActionExecutor
```

The event tap evaluates an immutable rule snapshot and immediately chooses pass
through or suppression. Action execution is queued separately. Mouse-down and
mouse-up remain paired if a rule changes during a click. Synthetic events are
marked so they cannot feed back into the input path.

Application-specific rules precede global rules while retaining their order.
The action engine checks posting permission, creates the complete modifier and
key sequence first, then posts modifiers down, key down/up, and modifiers up in
reverse order.

## Power and RGB flow

```text
SystemEventMonitor → combined system/display state → RGB coordinators → device adapters
```

USB work runs away from the UI actor. The configured profile is snapshotted
before sleep and retained until restoration completes. Duplicate notifications
do not overwrite it. A generation token invalidates obsolete retries.

Each USB restoration stage uses bounded retries after the configured delay:
immediately, 250 ms, 500 ms, 1 s, 2 s, 4 s, and 8 s. Drevo restoration performs
two additional reopen-and-send passes after a first successful command. Keyboard
and mouse progress independently.

The desk-light coordinator is isolated from USB work and follows CoreBluetooth's
main-actor delegate model. It records requested state rather than inventing a
physical state. Wake restoration waits at least one second, tries at most three
times with a 15-second operation timeout, and waits two seconds between attempts.
Manual commands, disabled automation, device removal, and a new sleep generation
invalidate pending work.

## RGB editor and scenes

The editor keeps independent keyboard and mouse drafts. Saving one device takes
an immutable snapshot, persists it, and sends it through the same coordinator
used for power events. Applying a device manually is independent of whether it
participates in sleep automation.

Temporary hardware preview is debounced and never persisted. Cancelling, closing
the editor, changing device, or sleeping restores or invalidates the preview.

Razer's optional `logo` profile permits independent scroll-wheel and logo zones.
Without it, both zones follow the primary profile for backward compatibility.

A custom spectrum palette stores 2–8 colors and a duration from 2 to 120 seconds.
`RGBGradient` interpolates channels with `ContinuousClock` and closes the last-to-
first segment. The software loop has its own generation, stops before sleep or a
new fixed effect, resumes when appropriate, and terminates after three consecutive
USB failures. Individual frames are not written to the log.

An `RGBScene` stores RGB configuration plus the last requested desk-light state
and color. It intentionally does not bind to a Bluetooth identifier, so a scene
can target the currently selected controller.

## Persistence and signing

`ConfigurationStore` writes sorted, pretty-printed JSON atomically to:

```text
~/Library/Application Support/PeripheralKit/settings.json
```

Optional fields preserve compatibility with older settings. Validation occurs
on load and before every save.

`Configuration/Defaults.xcconfig` provides portable ad-hoc signing and the
default install directory. It optionally includes ignored
`Configuration/Local.xcconfig`, allowing a developer to select a persistent
identity without committing machine-specific settings. A stable certificate,
bundle identifier, and bundle path help macOS preserve privacy grants across
builds. No key or certificate belongs in the repository.

## Project layout

- `Sources/PeripheralKit/App`: lifecycle, menu, settings, observable state.
- `Sources/PeripheralKit/Core`: configuration, rules, models, persistence.
- `Sources/PeripheralKit/Input`: event tap and Quartz action execution.
- `Sources/PeripheralKit/Hardware`: USB and Bluetooth protocol adapters.
- `Sources/PeripheralKit/System`: system events, HID inventory, restoration.
- `Tests/PeripheralKitTests`: packet, engine, persistence, and lifecycle tests.
- `PeripheralKit.xcodeproj`: authoritative application build.
- `Package.swift`: compatibility entry point for Swift command-line tooling.

The XCTest target has no app host. It compiles production sources without the
application and CLI entry points, injects hardware transports, collects Quartz
events in memory, and never reads the user's real settings.

## References and provenance

Apple API links and third-party protocol sources are listed in
`THIRD_PARTY_NOTICES.md`. OpenRazer was used only as protocol documentation; GPL
source is not imported. The current adapters use Apple IOKit directly and do not
bundle HIDAPI or OpenRGB.

## Known risks and roadmap

1. Physical device behavior can differ by firmware revision even when VID/PID
   matches.
2. macOS may suspend before best-effort pre-sleep writes finish.
3. Mouse-event source isolation is unavailable with the current public APIs.
4. Future work may include per-device input, generic editors, automation rules,
   real state readback where supported, and an optional OpenRGB backend.
