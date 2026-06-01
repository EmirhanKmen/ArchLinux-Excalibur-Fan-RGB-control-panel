#!/usr/bin/env bash
#
# caelestia-excalibur uninstaller
#
set -euo pipefail
CAEL_DST="$HOME/.config/quickshell/caelestia"

say() { printf '\033[1;32m::\033[0m %s\n' "$*"; }

say "Stopping fan daemon..."
sudo systemctl disable --now excalibur-fand.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/excalibur-fand.service /usr/local/bin/excalibur-fand.py
sudo systemctl daemon-reload

say "Removing CLI tools..."
sudo rm -f /usr/local/bin/excalibur-kbd /usr/local/bin/excalibur-fans

say "Removing QML files..."
rm -f "$CAEL_DST/services/Casper.qml" "$CAEL_DST/modules/dashboard/FanControl.qml"

if [ -f "$CAEL_DST/modules/dashboard/Content.qml.bak" ]; then
    say "Restoring original Content.qml..."
    mv -f "$CAEL_DST/modules/dashboard/Content.qml.bak" "$CAEL_DST/modules/dashboard/Content.qml"
else
    say "No Content.qml backup found — revert the Weather/Fans tab edit manually if needed."
fi

say "Done. The casper-wmi patch is left in place (it only hides the broken fan sensor)."
say "Restart the shell:  caelestia shell -k; caelestia shell -d"
