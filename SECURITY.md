# Security policy

## Supported versions

Security fixes are applied to the latest revision of the `main` branch. There
are no supported binary releases yet.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting feature when it is
available for this repository. Do not open a public issue for a vulnerability
that could expose user data, bypass macOS permissions, or send unsafe commands
to a device.

Include the affected commit, macOS version, hardware model, reproduction steps,
and the expected impact. Please avoid attaching personal configuration files,
Bluetooth identifiers, HID serial numbers, or unified-log exports unless they
have been redacted.

PeripheralKit does not use a network service or collect telemetry. Its elevated
macOS permissions still make input handling and device-command issues security
sensitive.
