import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A diff the way the coder shows it, from git's lines ("@@ -10,3 +10,4 @@", "-old", "+new",
// " around"):
//   @ line 10
//     around        (dim)
//   - old           (warn)
//   + new           (accent)
// Long ones are cut here, never in what's written.
ColumnLayout {
    id: root

    property var lines: []
    property int size: Metrics.fontSize
    property int max: 60

    spacing: 0

    // "@@ -a,b +c,d @@": the new file's line, or the old one's when nothing is left of it
    function shown(l: string): string {
        if (l.startsWith("@@")) {
            const m = l.match(/^@@ -(\d+)(?:,\d+)? \+(\d+)/);
            return m ? `@ line ${m[2] === "0" ? m[1] : m[2]}` : "@";
        }
        if (l.startsWith("\\"))
            return `  (${l.slice(2)})`; // \ No newline at end of file
        if (l.startsWith("+") || l.startsWith("-") || l.startsWith(" "))
            return `${l[0]} ${l.slice(1)}`;
        return l; // (binary)
    }

    Repeater {
        model: root.lines.slice(0, root.max)

        Label {
            required property string modelData
            readonly property bool note: modelData.startsWith("@@") || modelData.startsWith("\\") || modelData.startsWith("(")

            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.shown(modelData)
            color: modelData.startsWith("+") ? Colors.accent : modelData.startsWith("-") ? Colors.warn : Colors.dim
            font.pixelSize: note ? root.size - 3 : root.size - 1
        }
    }

    Label {
        visible: root.lines.length > root.max
        text: `... ${root.lines.length - root.max} lines more, shown cut`
        color: Colors.dim
        font.pixelSize: root.size - 3
    }
}
