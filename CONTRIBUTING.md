# Contributing

Thank you for helping improve PeripheralKit.

## Before opening a pull request

1. Use Xcode with the macOS 14 SDK or later.
2. Build the `PeripheralKit` scheme and run its XCTest suite.
3. Keep hardware access behind the existing adapters so tests never emit global
   input or require a physical device.
4. Add regression tests for packet, persistence, input, or lifecycle changes.
5. Do not commit local signing settings, device identifiers, logs, or user
   configuration files.

Copy `Configuration/Local.xcconfig.example` to
`Configuration/Local.xcconfig` only when you need a persistent local signing
identity. The copied file is ignored by Git.

## Protocol contributions

Document the hardware and firmware version used for validation. State the
source and license of every protocol reference. Do not copy code from a project
whose license is incompatible with PeripheralKit's MIT license.

Automated tests are not proof that a hardware command is safe. Clearly separate
simulated coverage from physical validation in documentation and pull requests.
