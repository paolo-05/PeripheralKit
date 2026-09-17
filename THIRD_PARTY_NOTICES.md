# Third-party notices

PeripheralKit contains an independent Swift implementation of device commands
that were researched against public protocol documentation and open-source
projects. The referenced projects are not bundled as dependencies.

## RazerControl

The Razer report layout was informed by
[RazerControl](https://github.com/pol-cova/RazerControl), which is distributed
under the MIT License:

> Copyright (c) 2026 Paul Contreras
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

## Protocol references

- [OpenRazer](https://github.com/openrazer/openrazer) was consulted as a Razer
  protocol reference. It is licensed under GPL-2.0. No OpenRazer source code is
  included in PeripheralKit.
- [dtv2](https://github.com/cobacdavid/dtv2), by David Cobac, documents Drevo
  Tyrfing V2 packets and identifies its source as CC BY-NC-SA. PeripheralKit
  uses an independently written Swift packet builder and does not bundle the
  Python project.
- [DrevoTyrfing](https://github.com/dennisblokland/DrevoTyrfing) documents the
  Drevo Tyrfing V2 packet format. The repository does not currently declare a
  software license; no source files from it are bundled here.
- [HIDAPI](https://github.com/libusb/hidapi) was used as background reference.
  PeripheralKit calls Apple's IOKit APIs directly and does not link HIDAPI.
- The HappyLighting/Triones commands were validated against a previously used
  local `RGB-remote/LED_source.py` script. That script is not distributed in
  this repository. The implemented byte sequences are documented in
  `Sources/PeripheralKit/Hardware/HappyLighting.swift` and its packet tests.

Apple framework names and product names belong to their respective owners.
PeripheralKit is not affiliated with Apple, Drevo, Razer, or the HappyLighting
vendors.
