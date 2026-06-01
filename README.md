# caelestia-excalibur

A **Fans + Keyboard RGB** dashboard tab for the [caelestia](https://github.com/caelestia-dots/shell) shell,
built for **Casper Excalibur** (Tongfang/Uniwill) gaming laptops on Linux.

It replaces the dashboard's *Weather* tab with a **Fans** tab that shows:

- 🌀 **Live fan speeds** — left (CPU) and right (GPU) fan RPM, read straight from the
  Embedded Controller (EC) so it never hangs.
- ⌨️ **Keyboard RGB control** — on/off slide switch, a colour picker (R/G/B sliders +
  presets) and a 3‑step brightness selector. Boots up at full power with your last colour.
- ♻️ **Reset button** — left‑click does a soft re‑apply, right‑click fully reloads the
  kernel module when the lighting gets stuck.

> Tested on **Casper Excalibur G870 (board NLXB, BIOS CQ121)**. Other Excalibur models
> using the same `casper-wmi` interface should work too.

---

## Why this exists

On these laptops the stock `casper-wmi` driver has two problems:

1. The keyboard LED only lights up if the WMI command uses **mode = static (1)**; the
   default tools send mode 0 (off), so the keyboard stays dark.
2. Reading the fan via WMI **hangs the kernel** (uninterruptible D‑state) on some BIOS
   revisions, which also freezes `sensors` and makes the CPU temperature read as 0 °C.

This project works around both: it drives the LED with the correct mode through the
existing `led_control` sysfs node, and reads the fans **directly from EC RAM** (registers
`0xB0–0xB3`) via a tiny daemon — no WMI, no hangs.

---

## How it works

| Piece | What it does |
|---|---|
| `shell/services/Casper.qml` | caelestia service: writes `led_control`, reads `/run/excalibur-fans` |
| `shell/modules/dashboard/FanControl.qml` | the "Fans" dashboard tab UI |
| `daemon/excalibur-fand.py` + `.service` | root service: reads fan RPM + temp from EC RAM → `/run/excalibur-fans` every 2 s |
| `bin/excalibur-kbd`, `bin/excalibur-fans` | shell‑independent CLI tools (use them from any bar / keybind) |
| `examples/waybar/` | ready‑to‑paste Waybar modules for non‑caelestia users |
| casper-wmi patch | hides the broken fan hwmon so `sensors`/CPU‑temp never hang |

LED command format written to `/sys/class/leds/casper::kbd_backlight/led_control`:
`<zone><mode><brightness><RRGGBB>` — e.g. `612ffffff` = all keys, static, full, white.

---

## Prerequisites

- [`caelestia-shell`](https://github.com/caelestia-dots/shell) (quickshell based)
- [`casper-keyboard-rgb`](https://aur.archlinux.org/packages/casper-keyboard-rgb) (AUR) —
  ships the `casper-wmi` kernel module, the `led_control` node and the udev rule:
  ```bash
  yay -S casper-keyboard-rgb
  ```
- `python`, `dkms`, `linux-headers`, `perl` (all usually already present)

---

## Installation

```bash
git clone https://github.com/<you>/caelestia-excalibur
cd caelestia-excalibur
chmod +x install.sh
./install.sh
```

The installer will:

1. Fork your caelestia config into `~/.config/quickshell/caelestia` (if not already).
2. Install the QML service + the Fans tab and patch `Content.qml`.
3. Install & enable the `excalibur-fand` fan‑reader service.
4. Patch & rebuild `casper-wmi` to hide the hanging fan hwmon.
5. Add you to the `video` group (for root‑less keyboard writes).

Then **reboot** (loads the patched module, clears the `video` group), and restart the shell:

```bash
caelestia shell -k; caelestia shell -d
```

Open the dashboard → **Fans** tab. 🎉

---

## Use without caelestia (any WM / bar)

The **backend is shell‑independent** — `install.sh` always installs the fan daemon,
the casper‑wmi fix and two CLI tools, whether or not caelestia is present:

```bash
excalibur-kbd white               # keyboard full white
excalibur-kbd color ff0000        # red
excalibur-kbd brightness 1        # dim
excalibur-kbd off / on / toggle
excalibur-fans                    # Left (CPU) 3590 RPM   Right (GPU) 3820 RPM   CPU 54°C
excalibur-fans --json             # Waybar-ready JSON
```

So you can wire it into **any** bar or keybind. Example for **Waybar** is in
[`examples/waybar/`](examples/waybar) — add the two `custom/excalibur-*` modules to your
config and the snippet to your CSS:

```jsonc
"custom/excalibur-fans": { "exec": "excalibur-fans --json", "return-type": "json", "interval": 2, "format": "󰈐 {}" },
"custom/excalibur-kbd":  { "format": "󰌌 RGB", "on-click": "excalibur-kbd toggle", "on-click-right": "excalibur-kbd white" }
```

Or bind keys in Hyprland:
```
bind = $mod, F1, exec, excalibur-kbd toggle
bind = $mod, F2, exec, excalibur-kbd white
```

Only the `Casper.qml` + `FanControl.qml` files are caelestia‑specific; everything else is generic.

## Manual tab setup

If the automatic `Content.qml` patch fails (different caelestia version), edit
`~/.config/quickshell/caelestia/modules/dashboard/Content.qml` yourself:

In the `dashboardTabs` array, replace the Weather entry:
```qml
{
    component: fansComponent,
    iconName: "mode_fan",
    text: qsTr("Fans"),
    enabled: true
}
```
…and replace the weather `Component`:
```qml
Component {
    id: fansComponent

    FanControl {}
}
```

---

## Troubleshooting

- **CPU temp shows 0 °C / `sensors` hangs** → the casper-wmi fan hwmon is still active.
  Re‑run the patch step in `install.sh` and reboot. A `casper-keyboard-rgb` package update
  reverts the patch — just run `./install.sh` again.
- **Keyboard won't light** → make sure you're in the `video` group (`id -nG | grep video`)
  and have logged out/in once.
- **Fans show "no sensor"** → check the daemon: `systemctl status excalibur-fand` and
  `cat /run/excalibur-fans` (should print `fan1 fan2 temp`).
- **Different fan register / RPM looks wrong** → dump your EC and adjust the offsets in
  `excalibur-fand.py` (see the DSDT `RPM1..RPM4` / `RTMP` fields).

## Uninstall

```bash
./uninstall.sh
```

---

## Credits

- [`thekayrasari/excalibur`](https://github.com/thekayrasari/excalibur) — confirmed the
  LED mode‑nibble protocol and fan decoding.
- [`casper-keyboard-rgb`](https://github.com/Jaeger0000/casper_excalibur_keyboard_rgb_linux)
  — the `casper-wmi` DKMS module.
- [caelestia](https://github.com/caelestia-dots/shell) — the shell this plugs into.

## License

MIT
