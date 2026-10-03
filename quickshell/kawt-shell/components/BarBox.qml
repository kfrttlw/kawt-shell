import QtQuick
import qs.config

// Bordered clickable box; children are laid out in a Row
Item {
    id: root

    property bool active: false
    property bool bordered: true
    readonly property bool hovered: area.containsMouse
    property alias spacing: row.spacing
    default property alias content: row.data

    signal clicked
    signal scrolled(int steps) // +1 = wheel up, -1 = wheel down

    implicitWidth: row.implicitWidth + Metrics.padding * 2
    implicitHeight: Metrics.barHeight - Metrics.spacing

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radius
        color: root.active || root.hovered ? Colors.hoverFill : root.bordered ? Colors.bg : "transparent"
        border.color: Colors.border
        border.width: root.bordered ? Metrics.borderWidth : 0
    }

    Row {
        id: row

        anchors.centerIn: parent
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
