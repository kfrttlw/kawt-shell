import QtQuick
import qs.config
import qs.components

// A small network drawn with characters. Still and dim while idle; while the agent works,
// a pulse runs through it from left to right and random nodes fire:
//         o       o       o
//       /   \   /   \   /   \
//     o ----- ● ----- o ----- o
//       \   /   \   /   \   /
//         ●       o       o
Item {
    id: root

    property bool active: false
    property string label: ""
    property int phase: 0

    readonly property list<string> rows: [
        "      o       o       o      ",
        "    /   \\   /   \\   /   \\    ",
        "  o ----- o ----- o ----- o  ",
        "    \\   /   \\   /   \\   /    ",
        "      o       o       o      "
    ]

    implicitWidth: art.implicitWidth
    implicitHeight: art.implicitHeight + caption.implicitHeight + 2

    // only ticks while active: idle costs nothing
    Timer {
        running: root.active && root.visible
        repeat: true
        interval: 140
        onTriggered: root.phase++
    }

    onActiveChanged: if (!active)
        phase = 0

    function html(): string {
        const lit = Colors.accent, node = Colors.dim, edge = Colors.border;
        const out = [];
        for (let r = 0; r < rows.length; r++) {
            let line = "";
            for (let c = 0; c < rows[r].length; c++) {
                const ch = rows[r][c];
                if (ch === "o") {
                    // the pulse: a band moving right, plus a few random sparks
                    const on = active && ((Math.floor(c / 4) - phase % 10 + 10) % 10 === 0 || Math.random() < 0.12);
                    line += on ? `<font color="${lit}">●</font>` : `<font color="${node}">o</font>`;
                } else if (ch === " ") {
                    line += "&nbsp;";
                } else {
                    const hot = active && (Math.floor(c / 4) - phase % 10 + 10) % 10 <= 1;
                    line += `<font color="${hot ? lit : edge}">${ch}</font>`;
                }
            }
            out.push(line);
        }
        return out.join("<br>");
    }

    Label {
        id: art

        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.StyledText
        // phase in the binding makes it redraw on every tick
        text: root.phase >= 0 ? root.html() : ""
    }

    Label {
        id: caption

        anchors.top: art.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.active ? `~ ${root.label}` : "idle"
        color: root.active ? Colors.accent : Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }
}
