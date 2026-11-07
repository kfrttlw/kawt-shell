pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What the machine has beyond the usual, for the profile's sys tab (scripts/hardware.sh): the
// bios version, the battery's charge thresholds, the keyboard light, the power profile. Each only
// where the machine has it: a thinkpad shows all of them, a pc perhaps none. Looked at when the
// tab opens (refresh), not all the time.
//   charge     the battery stops charging at `end` and starts again under `start`: a laptop on the
//              cable all day lives longer at 60-80%. Needs root: pkexec asks for your password.
//              Thinkpads keep it over a reboot, others may forget it
//   keyboard   through brightnessctl (logind lets you, no root)
//   profile    power-profiles-daemon: power-saver / balanced / performance
Singleton {
    id: root

    property string bios: ""
    property string code: "" // the model's number ("20T0S0..." on a thinkpad)
    property string battery: "" // its /sys folder, if it has charge thresholds
    property int chargeStart: -1
    property int chargeEnd: -1
    property string kbd: "" // the led's name ("tpacpi::kbd_backlight")
    property int kbdMax: 0
    property int kbdLevel: 0
    property string profile: "" // "" = no power-profiles-daemon
    property string status: "" // what the last change said, when it went wrong

    readonly property string script: `${Quickshell.shellDir}/scripts/hardware.sh`

    function refresh(): void {
        if (!reader.running)
            reader.running = true;
    }

    // stop at `end`, start again under `start`
    function setCharge(start: int, end: int): void {
        if (!battery || charger.running)
            return;
        status = "";
        charger.command = ["pkexec", "/bin/sh", script, "charge", battery, String(start), String(end)];
        charger.running = true;
    }

    function setKbd(level: int): void {
        if (!kbd)
            return;
        kbdLevel = level;
        Quickshell.execDetached(["brightnessctl", "-q", "-d", kbd, "set", String(level)]);
    }

    function setProfile(p: string): void {
        if (!profile)
            return;
        profile = p;
        Quickshell.execDetached(["powerprofilesctl", "set", p]);
    }

    Process {
        id: reader

        command: ["sh", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        v[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                const junk = /o\.?e\.?m|default string|to be filled|not applicable|not specified|^none$/i;
                root.bios = v.bios && !junk.test(v.bios) ? v.bios : "";
                root.code = v.code && !junk.test(v.code) ? v.code : "";
                root.battery = v.battery ?? "";
                root.chargeStart = v.chargestart ? parseInt(v.chargestart) : -1;
                root.chargeEnd = v.chargeend ? parseInt(v.chargeend) : -1;
                root.kbd = v.kbd ?? "";
                root.kbdMax = parseInt(v.kbdmax) || 0;
                root.kbdLevel = parseInt(v.kbdlevel) || 0;
                root.profile = v.profile ?? "";
            }
        }
    }

    Process {
        id: charger

        onExited: code => {
            // 126/127: pkexec said no (cancelled, or no polkit agent)
            root.status = code === 0 ? "" : code === 126 || code === 127 ? "not changed: no password given" : "the battery didn't take it";
            root.refresh();
        }
    }
}
