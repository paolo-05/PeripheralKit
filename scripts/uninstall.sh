#!/bin/zsh
set -euo pipefail

agent_file="$HOME/Library/LaunchAgents/com.local.mksleep-rgb.plist"
launchctl bootout "gui/$(id -u)/com.local.mksleep-rgb" 2>/dev/null || true
if [[ -f "$agent_file" ]]; then
  mv "$agent_file" "$HOME/.Trash/com.local.mksleep-rgb.plist"
fi

print "LaunchAgent rimosso. Configurazione e binario restano in ~/Library/Application Support/MKSleepRGB."
