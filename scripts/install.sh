#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
support_dir="$HOME/Library/Application Support/PeripheralKit"
app_bundle="$HOME/Applications/PeripheralKit.app"
legacy_agent="$HOME/Library/LaunchAgents/com.local.mksleep-rgb.plist"

# Reuse the already trusted local identity without modifying the keychain list.
if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
  identity="$(security find-identity -v -p codesigning | awk '/MKSleepRGB Local Code Signing|PeripheralKit Local Code Signing/ { print $2; exit }')"
  if [[ -n "$identity" ]]; then export CODESIGN_IDENTITY="$identity"; fi
fi
"$project_dir/scripts/build.sh"
mkdir -p "$HOME/Applications" "$support_dir/migration"
stamp="$(date +%Y%m%d-%H%M%S)"
staging="$HOME/Applications/.PeripheralKit-install-$$.app"
trap 'if [[ -d "$staging" ]]; then rm -rf -- "$staging"; fi' EXIT
ditto "$project_dir/dist/PeripheralKit.app" "$staging"
codesign --verify --strict "$staging"

# Stop only this utility before replacing its executable.
if pgrep -f "^$app_bundle/Contents/MacOS/PeripheralKit( |$)" >/dev/null; then
  osascript -e 'tell application id "com.local.peripheralkit" to quit'
  for attempt in {1..20}; do
    if ! pgrep -f "^$app_bundle/Contents/MacOS/PeripheralKit( |$)" >/dev/null; then break; fi
    sleep 0.1
  done
  if pgrep -f "^$app_bundle/Contents/MacOS/PeripheralKit( |$)" >/dev/null; then
    print -u2 'Chiudi PeripheralKit e ripeti l’installazione.'
    exit 1
  fi
fi
if [[ -d "$app_bundle" ]]; then mv "$app_bundle" "$support_dir/migration/PeripheralKit-$stamp.app"; fi
mv "$staging" "$app_bundle"

# The old JSON and signing identity remain in place. The app imports the JSON
# only if its new settings file does not exist.
if launchctl print "gui/$(id -u)/com.local.mksleep-rgb" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)/com.local.mksleep-rgb"
fi
if [[ -f "$legacy_agent" ]]; then
  mv "$legacy_agent" "$support_dir/migration/com.local.mksleep-rgb-$stamp.plist"
fi
open "$app_bundle" --args --settings --enable-login
print "Installato: $app_bundle"
print "Configurazione: $support_dir/settings.json"
print 'Autorizza PeripheralKit in Accessibilità e Monitoraggio input, poi abilita la rimappatura.'
if [[ "${CODESIGN_IDENTITY:--}" == '-' ]]; then
  print 'Firma ad hoc: per mantenere i permessi tra build, usa CODESIGN_IDENTITY con un’identità persistente.'
fi
