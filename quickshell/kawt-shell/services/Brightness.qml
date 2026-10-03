pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backlight via sysfs (read) + brightnessctl (write, works through logind without root)
Singleton {
    id: root

    property string device: ""
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
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0]?.split(",") ?? [];
                if (f.length >= 5) {
                    root.device = f[0];
                    root.raw = parseInt(f[2], 10);
                    root.max = parseInt(f[4], 10);
                }
            }
        }
    }

    FileView {
        id: file

        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        printErrors: false
        onLoaded: {
            if (!throttle.running)
                root.raw = parseInt(text().trim(), 10) || root.raw;
        }
    }

    // sysfs doesn't emit inotify events, so poll (cheap: just a file read)
    Timer {
        running: root.available
        repeat: true
        interval: 1000
        onTriggered: file.reload()
    }

    Timer {
        id: throttle

        interval: 40
        onTriggered: {
            if (root.pending >= 0)
                Quickshell.execDetached(["brightnessctl", "-q", "set", `${Math.round(root.pending * 100)}%`]);
            root.pending = -1;
        }
    }
}
