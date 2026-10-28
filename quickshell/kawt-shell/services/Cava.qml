pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

// Real audio levels for the bar's media button, from cava (scripts/cava.conf).
// One cava for all screens, and only while some player is playing: nothing runs in silence,
// or behind the lock screen. A frame like the last one changes nothing, so nothing is redrawn.
// While the player popover is open it shows a wide spectrum: cava runs with
// scripts/cava-wide.conf instead, and the bar's five bars are taken from those.
// Without cava installed, `available` is false and the bar falls back to its own animation.
Singleton {
    id: root

    readonly property int bars: 5 // = bars in scripts/cava.conf
    readonly property int max: 7 // = ascii_max_range
    property bool available: false
    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    property list<int> levels: new Array(bars).fill(0)
    readonly property int wideBars: 24 // = bars in scripts/cava-wide.conf
    readonly property int wideMax: 8
    readonly property bool wide: Panels.current === "player"
    property list<int> wideLevels: new Array(wideBars).fill(0)

    Process {
        running: true
        command: ["sh", "-c", "command -v cava"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() !== ""
        }
    }

    Process {
        id: cava

        running: root.available && root.playing && !Panels.locked && !root.wide && !Settings.lite
        command: ["cava", "-p", `${Quickshell.shellDir}/scripts/cava.conf`]
        // "3;5;1;0;2;" per frame
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(s => s !== "").map(Number);
                if (v.length === root.bars && v.some((x, i) => x !== root.levels[i]))
                    root.levels = v;
            }
        }
        onRunningChanged: if (!running)
            root.levels = new Array(root.bars).fill(0)
    }

    Process {
        running: root.available && root.playing && !Panels.locked && root.wide && !Settings.lite
        command: ["cava", "-p", `${Quickshell.shellDir}/scripts/cava-wide.conf`]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(s => s !== "").map(Number);
                if (v.length !== root.wideBars || v.every((x, i) => x === root.wideLevels[i]))
                    return;
                root.wideLevels = v;
                // the bar's five: the loudest of each fifth
                const five = [];
                for (let i = 0; i < root.bars; i++) {
                    const part = v.slice(Math.floor(i * root.wideBars / root.bars), Math.floor((i + 1) * root.wideBars / root.bars));
                    five.push(Math.round(Math.max(...part) * root.max / root.wideMax));
                }
                if (five.some((x, i) => x !== root.levels[i]))
                    root.levels = five;
            }
        }
        onRunningChanged: if (!running) {
            root.wideLevels = new Array(root.wideBars).fill(0);
            root.levels = new Array(root.bars).fill(0);
        }
    }
}
