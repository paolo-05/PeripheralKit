#!/bin/zsh
set -euo pipefail
app_bundle="$HOME/Applications/PeripheralKit.app"
if [[ -x "$app_bundle/Contents/MacOS/PeripheralKit" ]]; then
  "$app_bundle/Contents/MacOS/PeripheralKit" unregister-login
  if pgrep -f "^$app_bundle/Contents/MacOS/PeripheralKit( |$)" >/dev/null; then
    osascript -e 'tell application id "com.local.peripheralkit" to quit'
  fi
fi
print 'Avvio al login disabilitato. App e configurazione conservate.'
print 'Il vecchio LaunchAgent MKSleepRGB non viene riattivato automaticamente.'
