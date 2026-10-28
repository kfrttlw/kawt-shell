import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The bios-like check list at login (Settings.bootScreen, BootScreen.qml): once per login, not
// on every restart of kawt. The mark is a file in $XDG_RUNTIME_DIR, which the system empties
// when you log out. A few facts the services don't have yet this early come from here.
Scope {
    id: root

    property bool due: false // this login hasn't seen it yet
    property bool skipped: false // a key or a click on any screen: all of them go
    property var facts: ({})
    readonly property bool shown: due && Settings.loaded && Settings.bootScreen

    Process {
        running: true
        command: ["sh", "-c", 'm=${XDG_RUNTIME_DIR:-/tmp}/kawt-booted; [ -e "$m" ] && exit 0; : > "$m"; echo new; awk \'/MemTotal/ { printf "mem=%d MB\\n", $2 / 1024 }\' /proc/meminfo; df -h / | awk \'NR == 2 { print "disk=" $3 " / " $2 }\'; for b in /sys/class/power_supply/BAT*; do [ -r "$b/capacity" ] && echo "bat=$(cat "$b/capacity")%" && break; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines[0] !== "new")
                    return;
                const f = {};
                for (const l of lines.slice(1)) {
                    const i = l.indexOf("=");
                    if (i > 0)
                        f[l.slice(0, i)] = l.slice(i + 1);
                }
                root.facts = f;
                root.due = true;
            }
        }
    }

    Variants {
        model: root.shown ? Quickshell.screens : []

        BootScreen {
            required property ShellScreen modelData

            forScreen: modelData
            facts: root.facts
            skipped: root.skipped
            onSkip: root.skipped = true
            onDone: root.due = false
        }
    }
}
