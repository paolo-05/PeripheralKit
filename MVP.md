# PeripheralKit initial implementation scope

## Authorized scope

The initial increment delivered the native application shell and mouse mapping
while preserving the existing Drevo Tyrfing V2 and Razer DeathAdder V2 sleep/RGB
behavior. The wider product document remains a roadmap, not a promise that every
feature is included in the first release.

## Required verification

- Menu-bar accessory app with reopenable settings, quit, and a global remapping
  switch.
- Real Accessibility and Input Monitoring state, requested only after an explicit
  user action.
- Global extra-button capture that can be cancelled and never observes typed
  keyboard text.
- Button 4 → Control–Left, button 5 → Control–Right, Mission Control, and a
  configurable shortcut.
- Event consume/pass-through behavior, disabled rules, and `--safe-mode`.
- HID inventory, bounded diagnostics, and persistent configuration.
- Drevo/Razer RGB, system/display sleep handling, and configured-profile restore.
- Login startup through `SMAppService`.
- Automated unit tests kept separate from permission and physical-hardware tests.

## Initially excluded

Per-mouse mapping isolation, a generic device editor, shell or AppleScript
actions, OpenRGB TCP, dynamic plugins, and reliable readback of RGB state changed
by another application. Simulated behavior must never be presented as physical
hardware support.

## Manual acceptance

1. Install a consistently signed app, authorize Accessibility and Input
   Monitoring, and reopen it if requested.
2. Create at least two Spaces and enable Control–Left/Right under Mission Control
   keyboard shortcuts.
3. Test the rear and front buttons in Safari and Finder. With consumption enabled,
   Back/Forward must not also occur.
4. Capture one extra button and cancel a second capture. Left and right click must
   never be intercepted.
5. Disable remapping, then repeat with `--safe-mode` and verify normal input.
6. Test display sleep, full system sleep, wake, and USB disconnect/reconnect for
   both supported devices.
7. Confirm restoration of the configured rainbow, spectrum, or imported profile,
   not an unrelated effect selected in another application.
8. Verify launch at login after installation and a real login cycle.
