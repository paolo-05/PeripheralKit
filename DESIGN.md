# PeripheralKit design

PeripheralKit is opened briefly at a desk, during the day or at night. It follows
the system light or dark appearance.

The interface uses grouped SwiftUI forms, a sidebar list, system typography, and
semantic colors. Accent color is limited to controls and selection. There are no
decorative animations, dashboard chrome, or repeated card containers. The window
is resizable, the sidebar is compact, content scrolls, errors remain visible, and
actions are recoverable. The current application UI is written in Italian; the
repository and contributor documentation are in English.

The RGB editor follows the familiar flow of peripheral configurators: device
selection, schematic preview, effect list, and color or slider controls. Lighting
and sleep behavior are separate tabs. Drafts become persistent only through Save
and Apply. Previews are explicitly approximate, and unsupported per-key editing
is never implied. Razer wheel and logo zones have distinct selection and preview.
Scenes live in their own tab, and live hardware preview is temporary and
cancellable.
