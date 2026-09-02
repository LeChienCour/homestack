#!/bin/bash
# =============================================================================
# install-podman-autostart.sh
# Instala un Launch Agent que arranca Podman Machine al login.
# Uso: bash scripts/install-podman-autostart.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/start-podman-machine.sh"
PLIST_LABEL="com.homestack.podman-machine"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

chmod +x "$SCRIPT"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/podman-machine-start.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/podman-machine-start.log</string>
</dict>
</plist>
EOF

# Cargar el agente (o recargar si ya existía)
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

echo "✓ Launch Agent instalado: $PLIST_PATH"
echo "  Se ejecutará en cada login."
echo "  Logs en: /tmp/podman-machine-start.log"
