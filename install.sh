#!/usr/bin/env bash
#
# caelestia-excalibur installer
#
# Backend (universal, any WM/bar):  fan reader daemon + casper-wmi fix + CLI tools.
# Frontend (optional):              caelestia "Fans" dashboard tab.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAEL_SRC="/etc/xdg/quickshell/caelestia"
CAEL_DST="$HOME/.config/quickshell/caelestia"

say()  { printf '\033[1;32m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# ── prerequisites ───────────────────────────────────────────────────
say "Checking prerequisites..."
command -v python3 >/dev/null || die "python3 is required."
[ -d /usr/src/casper-wmi-* ] 2>/dev/null || warn "casper-wmi DKMS not found. Keyboard RGB needs it:  yay -S casper-keyboard-rgb"

HAS_CAEL=0
if command -v qs >/dev/null && { [ -d "$CAEL_SRC" ] || [ -d "$CAEL_DST" ]; }; then
    HAS_CAEL=1
fi

# ════════════════════════════════════════════════════════════════════
#  BACKEND (everyone)
# ════════════════════════════════════════════════════════════════════

# fan/temp reader daemon (reads EC RAM -> /run/excalibur-fans, never hangs)
say "Installing fan reader daemon (sudo)..."
sudo install -Dm755 "$REPO_DIR/daemon/excalibur-fand.py"      /usr/local/bin/excalibur-fand.py
sudo install -Dm644 "$REPO_DIR/daemon/excalibur-fand.service" /etc/systemd/system/excalibur-fand.service
sudo systemctl daemon-reload
sudo systemctl enable --now excalibur-fand.service

# CLI tools
say "Installing CLI tools (excalibur-kbd, excalibur-fans)..."
sudo install -Dm755 "$REPO_DIR/bin/excalibur-kbd"  /usr/local/bin/excalibur-kbd
sudo install -Dm755 "$REPO_DIR/bin/excalibur-fans" /usr/local/bin/excalibur-fans

# patch casper-wmi: hide the broken fan hwmon (otherwise the WMI fan read
# hangs `sensors` and freezes the CPU temperature)
SRC=$(ls -d /usr/src/casper-wmi-*/ 2>/dev/null | head -1 || true)
if [ -n "${SRC:-}" ] && grep -q "return 0444" "$SRC/casper-wmi.c" 2>/dev/null; then
    say "Patching casper-wmi (disable hanging fan hwmon) + rebuilding..."
    sudo cp "$SRC/casper-wmi.c" "$SRC/casper-wmi.c.bak"
    sudo sed -i 's/return 0444;/return 0;/; s/return 0644;/return 0;/' "$SRC/casper-wmi.c"
    VER=$(basename "$SRC" | sed 's/casper-wmi-//;s#/##')
    sudo dkms build "casper-wmi/$VER" --force && sudo dkms install "casper-wmi/$VER" --force || warn "dkms rebuild failed — see README."
else
    say "casper-wmi already patched or not present."
fi

# video group (root-less keyboard writes)
if ! id -nG | tr ' ' '\n' | grep -qx video; then
    say "Adding $USER to the 'video' group..."
    sudo usermod -aG video "$USER"
    NEED_RELOGIN=1
fi

# ════════════════════════════════════════════════════════════════════
#  FRONTEND (caelestia only)
# ════════════════════════════════════════════════════════════════════
if [ "$HAS_CAEL" = 1 ]; then
    if [ ! -d "$CAEL_DST" ]; then
        say "Forking caelestia config to $CAEL_DST ..."
        mkdir -p "$(dirname "$CAEL_DST")"
        cp -r "$CAEL_SRC" "$CAEL_DST"
    fi

    say "Installing caelestia QML (service + Fans tab)..."
    install -Dm644 "$REPO_DIR/shell/services/Casper.qml"              "$CAEL_DST/services/Casper.qml"
    install -Dm644 "$REPO_DIR/shell/modules/dashboard/FanControl.qml" "$CAEL_DST/modules/dashboard/FanControl.qml"

    CONTENT="$CAEL_DST/modules/dashboard/Content.qml"
    if grep -q "fansComponent" "$CONTENT" 2>/dev/null; then
        say "Content.qml already patched."
    elif [ -f "$CONTENT" ]; then
        say "Patching Content.qml (backup .bak) ..."
        perl -0777 -i.bak -pe '
            s/\{\s*component:\s*weatherComponent,\s*iconName:\s*"cloud",\s*text:\s*qsTr\("Weather"\),\s*enabled:\s*Config\.dashboard\.showWeather\s*\}/{\n                component: fansComponent,\n                iconName: "mode_fan",\n                text: qsTr("Fans"),\n                enabled: true\n            }/s;
            s/Component\s*\{\s*id:\s*weatherComponent\s*WeatherTab\s*\{\}\s*\}/Component {\n                id: fansComponent\n\n                FanControl {}\n            }/s;
        ' "$CONTENT"
        grep -q "fansComponent" "$CONTENT" || warn "Auto-patch failed — see README 'Manual tab setup'."
    fi
else
    say "caelestia not detected — installed backend + CLI only."
    say "Add it to your bar (e.g. Waybar) — see examples/waybar/ and use 'excalibur-kbd' / 'excalibur-fans'."
fi

# ── done ────────────────────────────────────────────────────────────
say "Done!"
echo
echo "Next steps:"
[ "${NEED_RELOGIN:-0}" = 1 ] && echo "  * Log out/in (or reboot) so the 'video' group takes effect."
echo "  * Reboot recommended so the patched casper-wmi module loads."
[ "$HAS_CAEL" = 1 ] && echo "  * Restart shell: caelestia shell -k; caelestia shell -d  → dashboard 'Fans' tab"
echo "  * Test from a terminal:  excalibur-kbd white   &&   excalibur-fans"
