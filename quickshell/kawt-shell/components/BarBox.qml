import QtQuick
import qs.config

// Clickable box; children are laid out in a Row. A raised button that goes down while it's
// pressed, and stays down while it's `down` (chosen, or its panel open). A button on the bar
// itself is `plain` (any parent with `plainButtons: true` makes its buttons so,
// modules/bar/Bar.qml does): no frame of its own, filled while hovered, down while open.
Item {
    id: root

    property bool active: false
    property bool bordered: false
    property bool down: active
    property bool plain: inPlainRow
    property bool dotted: false // the dotted face (a window button in focus)
    readonly property bool raised: !plain
    readonly property bool hovered: area.containsMouse
    readonly property bool pushed: area.pressed || down // drawn pressed in
    property alias spacing: row.spacing
    default property alias content: row.data

    // asked once, when it's made: buttons don't move between rows
    readonly property bool inPlainRow: {
        for (let p = parent; p; p = p.parent)
            if (p.plainButtons === true)
                return true;
        return false;
    }

    signal clicked
    signal scrolled(int steps) // +1 = wheel up, -1 = wheel down

    // no frame: less room around it
    implicitWidth: row.implicitWidth + (bordered || raised ? Metrics.padding * 2 : Metrics.padding)
    implicitHeight: Metrics.barHeight - Metrics.spacing

    // the face, raised or pressed in; a plain one only shows it while hovered or down.
    // A hovered raised one lights up a little (old systems didn't; a mouse wants to know)
    Rectangle {
        anchors.fill: parent
        visible: root.raised || root.hovered || root.pushed
        color: root.raised && root.hovered && !root.pushed ? Colors.mix(Colors.face, Colors.hi, 0.12) : root.raised || root.pushed ? Colors.face : Colors.hoverFill

        Dots {
            visible: root.dotted
            anchors.fill: parent
            anchors.margins: 2
        }

        Bevel {
            visible: root.raised || root.pushed
            style: root.pushed ? "pressed" : "raised"
        }
    }

    // pressed in, the inside goes a pixel right and down with it
    Row {
        id: row

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.pushed ? 1 : 0
        anchors.verticalCenterOffset: root.pushed ? 1 : 0
    }

    MouseArea {
        id: area

        property real wheelAcc: 0

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: wheel => {
            // touchpads send many small deltas; emit one step per notch (120)
            wheelAcc += wheel.angleDelta.y;
            while (Math.abs(wheelAcc) >= 120) {
                root.scrolled(wheelAcc > 0 ? 1 : -1);
                wheelAcc -= wheelAcc > 0 ? 120 : -120;
            }
        }
    }
}
