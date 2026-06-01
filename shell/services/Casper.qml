pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Casper Excalibur fan speeds + keyboard RGB control via the casper-wmi
// kernel module (bundled with the casper-keyboard-rgb package).
//   fans : /sys/class/hwmon/*/fan{1,2}_input  (name == "casper_wmi")
//          fan1 = cpu_fan_speed (left), fan2 = gpu_fan_speed (right)
//   led  : /sys/class/leds/casper::kbd_backlight/led_control
//          format <zone:3-6><0><brightness:0-2><RRGGBB>
//          602FFFFFF = all keys, full brightness, white  -> ON
//          600000000 = all keys, brightness 0           -> OFF
Singleton {
    id: root

    readonly property string ledPath: "/sys/class/leds/casper::kbd_backlight/led_control"

    // Keyboard backlight state. led_control format: <zone><mode><brightness><RRGGBB>
    //   zone 6 = all keyboard, mode 1 = static, brightness 0-2.
    //   e.g. 612ffffff = static white full.  600000000 = off.
    property bool ledOn: true
    property int brightness: 2          // 0-2; reset to full at startup
    property string colorHex: persist.colorHex   // "RRGGBB", no '#'
    property bool resetting: false

    // Left fan (CPU) and right fan (GPU) speeds in RPM
    property int leftFan: 0
    property int rightFan: 0
    property bool available: false

    function ledCmd(): string {
        if (!ledOn || brightness <= 0)
            return "600000000";
        return "61" + brightness + colorHex; // zone6, static mode, brightness, RRGGBB
    }

    function applyLed(): void {
        Quickshell.execDetached(["sh", "-c", `printf '%s' '${ledCmd()}' > '${ledPath}'`]);
    }

    function toggle(): void {
        setOn(!ledOn);
    }

    function setOn(on: bool): void {
        ledOn = on;
        if (on && brightness <= 0)
            brightness = 2;
        applyLed();
    }

    function setColor(hex: string): void {
        colorHex = hex;
        persist.colorHex = hex;
        if (ledOn)
            applyLed();
    }

    function setBrightness(b: int): void {
        brightness = Math.max(0, Math.min(2, b));
        ledOn = brightness > 0;
        applyLed();
    }

    PersistentProperties {
        id: persist

        reloadableId: "casperLed"

        property string colorHex: "ffffff"
    }

    Component.onCompleted: {
        // boot / shell start -> full power, on, last colour
        ledOn = true;
        brightness = 2;
        applyLed();
    }

    // Soft reset: cycle the LED value a few times to un-stick a glitched EC.
    // No root required.
    function softReset(): void {
        resetting = true;
        const target = ledCmd();
        Quickshell.execDetached(["sh", "-c", `for i in 1 2 3; do printf '%s' '600000000' > '${ledPath}'; sleep 0.12; printf '%s' '${target}' > '${ledPath}'; sleep 0.12; done`]);
        resetTimer.restart();
    }

    // Hard reset: reload the casper-wmi kernel module, then re-apply the LED.
    // Prompts for a password via pkexec.
    function hardReset(): void {
        resetting = true;
        Quickshell.execDetached(["pkexec", "sh", "-c", "modprobe -r casper_wmi; sleep 0.4; modprobe casper_wmi"]);
        reapplyTimer.restart();
    }

    Timer {
        id: resetTimer
        interval: 1000
        onTriggered: root.resetting = false
    }

    Timer {
        id: reapplyTimer
        interval: 2000
        onTriggered: {
            root.applyLed();
            root.resetting = false;
        }
    }

    // Fan speeds + CPU temp are published by the excalibur-fand systemd
    // service, which reads them straight from EC RAM (no WMI -> never hangs).
    // File format: "fan1 fan2 temp"
    property int cpuTemp: 0

    Timer {
        running: true
        repeat: true
        interval: 2000
        triggeredOnStart: true
        onTriggered: fanProc.running = true
    }

    Process {
        id: fanProc
        command: ["cat", "/run/excalibur-fans"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/).map(n => parseInt(n, 10));
                if (parts.length >= 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
                    root.leftFan = parts[0];
                    root.rightFan = parts[1];
                    if (parts.length >= 3 && !isNaN(parts[2]))
                        root.cpuTemp = parts[2];
                    root.available = true;
                } else {
                    root.available = false;
                }
            }
        }
    }

}
