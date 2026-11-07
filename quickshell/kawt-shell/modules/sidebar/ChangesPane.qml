import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// [changes] in the coder: every file the agent changed this session, by edit or by command,
// each as one diff from how it was before the agent's first change to it to now:
//   -- 3 files changed, from before the agent to now --
//   ~ src/app.py                                    +4 −1   [undo]
//     @ line 10
//       around
//     - old
//     + new
//   + tests/new.txt                                  new    [undo]
//   - old.log                                        gone   [undo]
// [undo] on one puts back that file alone (the [undo] under the steps, all of them). Made only
// while it's open, in coder mode. A diff is read when its file comes into view, and again when
// the file is changed once more: only those, as they wait in line with the agent's own jobs (a
// build may have changed hundreds).
ListView {
    id: root

    property var diffs: ({}) // key -> { how, lines, plus, minus }; null: couldn't be read
    // Plain JS objects, changed in place: an answer that comes after the pane is gone still
    // finds them (and stops there)
    property var turn: ({}) // key -> how many times its file changed while open
    property var asked: ({}) // key -> the turn a read is out for
    property var alive: ({ yes: true })
    readonly property int size: Math.max(8, Metrics.fontSize + Settings.aiZoom)
    readonly property var keys: Object.keys(Coder.changedFiles).sort((a, b) => Coder.changedFiles[a].path.localeCompare(Coder.changedFiles[b].path))

    // a file's diff, once (until it changes again)
    function need(k: string): void {
        const t = turn[k] ?? 0;
        if (k in diffs || asked[k] === t)
            return;
        asked[k] = t;
        const life = alive, turns = turn;
        Coder.diffOf(k, d => {
            if (!life.yes)
                return;
            if ((turns[k] ?? 0) !== t) {
                root.need(k); // changed while it was read: once more
                return;
            }
            const all = Object.assign({}, root.diffs);
            all[k] = d;
            root.diffs = all;
        });
    }

    Component.onDestruction: alive.yes = false

    Connections {
        target: Coder

        // changed once more: read again (the ones in view at once: their d turns undefined)
        function onFilesTouched(keys: var): void {
            const all = Object.assign({}, root.diffs);
            for (const k of keys) {
                root.turn[k] = (root.turn[k] ?? 0) + 1;
                delete all[k];
            }
            root.diffs = all;
        }
    }

    clip: true
    spacing: Metrics.spacing
    boundsBehavior: Flickable.StopAtBounds
    model: keys

    header: Label {
        width: root.width
        height: implicitHeight + Metrics.spacing
        text: root.keys.length ? `-- ${root.keys.length} file${root.keys.length === 1 ? "" : "s"} changed, from before the agent to now --` : "-- nothing changed --"
        color: Colors.dim
        font.pixelSize: root.size - 2
    }

    delegate: ColumnLayout {
        id: file

        required property string modelData
        readonly property var c: Coder.changedFiles[modelData] ?? null
        readonly property var d: root.diffs[modelData] // undefined: still reading
        readonly property string how: d ? d.how : ""

        width: root.width
        spacing: 2
        Component.onCompleted: root.need(modelData)
        onDChanged: if (d === undefined)
            root.need(modelData)

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Label {
                text: file.how === "new" ? "+" : file.how === "gone" ? "-" : "~"
                color: file.how === "new" ? Colors.accent : file.how === "gone" ? Colors.warn : Colors.fg
                font.pixelSize: root.size
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                text: file.c ? file.c.path : ""
                color: Colors.fg
                font.pixelSize: root.size
            }

            Label {
                text: file.d === undefined ? "..." : file.d === null ? "can't be read" : file.how === "new" ? "new" : file.how === "gone" ? "gone" : file.d.lines.length === 0 ? "as it was" : file.d.lines[0] === "(binary)" ? "binary" : `+${file.d.plus} −${file.d.minus}`
                color: Colors.dim
                font.pixelSize: root.size - 2
            }

            BracketButton {
                label: "undo"
                textColor: Colors.warn
                bordered: false
                enabled: !Coder.running && !Coder.settling
                onClicked: Coder.putBack(file.modelData)
            }
        }

        DiffLines {
            Layout.fillWidth: true
            Layout.leftMargin: root.size * 2
            visible: lines.length > 0
            lines: file.d ? file.d.lines : []
            size: root.size
            max: 150
        }
    }
}
