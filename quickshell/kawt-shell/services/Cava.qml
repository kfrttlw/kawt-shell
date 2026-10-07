pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Real audio levels for the bar's media button, from cava (scripts/cava.conf).
// One cava for all screens, and only while some player is playing: nothing runs in silence.
// Without cava installed, `available` is false and the bar falls back to its own animation.
Singleton {
    id: root

    readonly property int bars: 5 // = bars in scripts/cava.conf
    readonly property int max: 7 // = ascii_max_range
    property bool available: false
    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    property list<int> levels: new Array(bars).fill(0)

    Process {
        running: true
        command: ["sh", "-c", "command -v cava"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() !== ""
        }
    }

    Process {
        id: cava

        running: root.available && root.playing
        command: ["cava", "-p", `${Quickshell.shellDir}/scripts/cava.conf`]
        // "3;5;1;0;2;" per frame
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(s => s !== "").map(Number);
                if (v.length === root.bars)
                    root.levels = v;
            }
        }
        onRunningChanged: if (!running)
            root.levels = new Array(root.bars).fill(0)
    }
}
