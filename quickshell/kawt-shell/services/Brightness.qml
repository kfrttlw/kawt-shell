pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backlight via sysfs (read) + brightnessctl (write, works through logind without root).
// No backlight (a desktop): the monitors' own brightness over DDC/CI instead, all of them
// together (scripts/ddc.sh, needs ddcutil). That's slow (a monitor takes a moment per change):
// a change goes out at most every 300 ms and nothing is polled, so what the monitor's own
// buttons change shows the next time kawt starts.
Singleton {
    id: root

    property string device: "" // the backlight, or "monitors (ddc)"
    property bool ddc: false
    readonly property string ddcScript: `${Quickshell.shellDir}/scripts/ddc.sh`
    property int max: 0
    property int raw: 0
    readonly property bool available: device !== "" && max > 0
    readonly property real value: available ? raw / max : 0
    readonly property int pct: Math.round(value * 100)

    property real pending: -1

    function set(v: real): void {
        if (!available)
            return;
        v = Math.max(0.01, Math.min(1, v));
        raw = Math.round(v * max);
        pending = v;
        if (!throttle.running)
            throttle.start();
    }

    function step(delta: real): void {
        set(value + delta);
    }

    // brightnessctl -m -> "amdgpu_bl1,backlight,65535,100%,65535"
    Process {
        running: true
        command: ["sh", "-c", "brightnessctl -m -c backlight 2> /dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0]?.split(",") ?? [];
                if (f.length >= 5) {
                    root.device = f[0];
                    root.raw = parseInt(f[2], 10);
                    root.max = parseInt(f[4], 10);
                } else {
                    ddcFind.running = true;
                }
            }
        }
    }

    // the monitors that answer over DDC/CI, and the first one's brightness in percent
    Process {
        id: ddcFind

        command: ["sh", root.ddcScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = parseInt(text.trim(), 10);
                if (p >= 0 && p <= 100) {
                    root.ddc = true;
                    root.max = 100;
                    root.raw = p;
                    root.device = "monitors (ddc)";
                }
            }
        }
    }

    Process {
        id: ddcSet
    }

    FileView {
        id: file

        path: root.device && !root.ddc ? `/sys/class/backlight/${root.device}/brightness` : ""
        printErrors: false
        onLoaded: {
            if (!throttle.running)
                root.raw = parseInt(text().trim(), 10) || root.raw;
        }
    }

    // sysfs doesn't emit inotify events, so poll: once a second while nothing happens, four
    // times a second for a few seconds after a change (keys are pressed in bursts), so the osd
    // follows the keys. Changes made through kawt (the bar, `kawt brightness up` on the
    // brightness keys, see hypr/kawt.lua) show at once and need no poll at all.
    property bool busy: false

    onRawChanged: {
        busy = true;
        calm.restart();
    }

    // (not while locked: nothing shows it then; kawt's own changes, like the dim before the
    // lock, set `raw` themselves)
    Timer {
        running: root.available && !root.ddc && !Panels.locked
        repeat: true
        interval: root.busy ? 250 : 1000
        onTriggered: file.reload()
    }

    Timer {
        id: calm

        interval: 3000
        onTriggered: root.busy = false
    }

    Timer {
        id: throttle

        interval: root.ddc ? 300 : 40
        onTriggered: {
            if (root.pending < 0)
                return;
            if (!root.ddc) {
                Quickshell.execDetached(["brightnessctl", "-q", "set", `${Math.round(root.pending * 100)}%`]);
            } else if (ddcSet.running) {
                restart(); // the monitors are still busy with the last one
                return;
            } else {
                ddcSet.command = ["sh", root.ddcScript, "set", String(Math.round(root.pending * 100))];
                ddcSet.running = true;
            }
            root.pending = -1;
        }
    }
}
