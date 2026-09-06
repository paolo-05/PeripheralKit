#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
support_dir="$HOME/Library/Application Support/MKSleepRGB"
app_bundle="$HOME/Applications/MKSleepRGB.app"
app_binary="$app_bundle/Contents/MacOS/mksleep-rgb"
agent_file="$HOME/Library/LaunchAgents/com.local.mksleep-rgb.plist"
log_file="$HOME/Library/Logs/MKSleepRGB.log"
signing_dir="$support_dir/signing"
signing_keychain="$signing_dir/MKSleepRGB.keychain-db"
signing_password_file="$signing_dir/keychain-password"
signing_certificate="$signing_dir/certificate.pem"
signing_name="MKSleepRGB Local Code Signing"

cd "$project_dir"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift build -c release --disable-sandbox

mkdir -p "$support_dir" "$app_bundle/Contents/MacOS" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs" "$signing_dir"
chmod 700 "$signing_dir"
install -m 755 ".build/release/mksleep-rgb" "$app_binary"
install -m 644 "resources/Info.plist" "$app_bundle/Contents/Info.plist"

if [[ ! -f "$signing_keychain" || ! -f "$signing_password_file" ]]; then
  private_key="$signing_dir/private-key.pem"
  identity_bundle="$signing_dir/identity.p12"

  openssl rand -hex 32 > "$signing_password_file"
  chmod 600 "$signing_password_file"
  signing_password="$(<"$signing_password_file")"

  openssl req -new -newkey rsa:3072 -nodes -x509 -days 7300 \
    -config "$project_dir/resources/local-codesign-openssl.cnf" \
    -keyout "$private_key" -out "$signing_certificate"
  openssl pkcs12 -export -legacy -inkey "$private_key" -in "$signing_certificate" \
    -name "$signing_name" -passout "pass:$signing_password" -out "$identity_bundle"

  security create-keychain -p "$signing_password" "$signing_keychain"
  security unlock-keychain -p "$signing_password" "$signing_keychain"
  security import "$identity_bundle" -k "$signing_keychain" -P "$signing_password" -T /usr/bin/codesign
  security add-trusted-cert -r trustRoot -p codeSign -k "$signing_keychain" "$signing_certificate"
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
    -k "$signing_password" "$signing_keychain" >/dev/null

  rm -f "$private_key" "$identity_bundle"
else
  signing_password="$(<"$signing_password_file")"
  security unlock-keychain -p "$signing_password" "$signing_keychain"
fi

# codesign only resolves identities from keychains in the user's search list,
# even when --keychain is also supplied.
security list-keychains -d user -s \
  "$HOME/Library/Keychains/login.keychain-db" "$signing_keychain"

signing_hash="$(security find-identity -v -p codesigning "$signing_keychain" | awk -v name="$signing_name" '$0 ~ name { print $2; exit }')"
if [[ -z "$signing_hash" ]]; then
  print -u2 "Identità di firma locale non valida: $signing_name"
  exit 1
fi

codesign --force --sign "$signing_hash" --keychain "$signing_keychain" \
  --identifier com.local.mksleep-rgb "$app_bundle"
codesign --verify --strict --verbose=2 "$app_bundle"
if [[ ! -f "$support_dir/config.json" ]]; then
  install -m 644 "config.example.json" "$support_dir/config.json"
fi

launchctl bootout "gui/$(id -u)/com.local.mksleep-rgb" 2>/dev/null || true

escaped_binary=${app_binary//&/&amp;}
escaped_config=${support_dir//&/&amp;}/config.json
escaped_log=${log_file//&/&amp;}

{
  print '<?xml version="1.0" encoding="UTF-8"?>'
  print '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  print '<plist version="1.0"><dict>'
  print '  <key>Label</key><string>com.local.mksleep-rgb</string>'
  print '  <key>ProgramArguments</key><array>'
  print "    <string>$escaped_binary</string>"
  print '    <string>daemon</string>'
  print '    <string>--config</string>'
  print "    <string>$escaped_config</string>"
  print '  </array>'
  print '  <key>RunAtLoad</key><true/>'
  print '  <key>KeepAlive</key><true/>'
  print '  <key>ProcessType</key><string>Interactive</string>'
  print "  <key>StandardOutPath</key><string>$escaped_log</string>"
  print "  <key>StandardErrorPath</key><string>$escaped_log</string>"
  print '</dict></plist>'
} > "$agent_file"

plutil -lint "$agent_file"
launchctl bootstrap "gui/$(id -u)" "$agent_file"
launchctl kickstart -k "gui/$(id -u)/com.local.mksleep-rgb"

print "Installato: $app_bundle"
print "Configurazione: $support_dir/config.json"
print "Log: $log_file"
print "Firma persistente: $signing_name ($signing_hash)"
print "Autorizzazione: open -n '$app_bundle' --args authorize"
