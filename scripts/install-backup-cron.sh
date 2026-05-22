#!/usr/bin/env bash
# =============================================================================
# install-backup-cron.sh — Programa el backup diario en macOS launchd
# =============================================================================
# Crea un LaunchAgent que corre backup.sh cada noche a las 3:00 AM.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

PLIST_NAME="com.diego.homestack.backup"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
LOG_DIR="$HOME/Library/Logs/homestack"

mkdir -p "$LOG_DIR"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$BACKUP_SCRIPT</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>$LOG_DIR/backup.log</string>

    <key>StandardErrorPath</key>
    <string>$LOG_DIR/backup.error.log</string>

    <key>WorkingDirectory</key>
    <string>$REPO_DIR</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
EOF

# Cargar el agent
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "✓ LaunchAgent instalado: $PLIST_PATH"
echo "✓ Backup programado todos los días a las 3:00 AM"
echo "✓ Logs en: $LOG_DIR/"
echo ""
echo "Para probar manualmente:"
echo "  launchctl start $PLIST_NAME"
echo ""
echo "Para deshabilitar:"
echo "  launchctl unload $PLIST_PATH"
