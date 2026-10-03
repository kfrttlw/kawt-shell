import QtQuick
import qs.config

// Segmented LED-style meter; drag or scroll to change
Item {
    id: root

    property real value: 0
    property real wheelStep: 0.05
    readonly property int segWidth: 4
    readonly property int segGap: 2
    readonly property int segCount: Math.max(1, Math.floor((width - 4 + segGap) / (segWidth + segGap)))
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * segCount)

    signal moved(real value)

    implicitHeight: 12

    // don't assign `value` here: that would break the caller's binding (e.g. to the sink volume)
    function set(v: real): void {
        moved(Math.max(0, Math.min(1, v)));
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        border.color: Colors.border
        border.width: Metrics.borderWidth
        radius: Metrics.radius
    }

    Row {
        anchors.fill: parent
        anchors.margins: 2
        spacing: root.segGap

        Repeater {
            model: root.segCount

            Rectangle {
                required property int index

                width: root.segWidth
                height: parent.height
                color: index < root.lit ? Colors.fg : Colors.hoverFill
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => root.set(mouse.x / width)
        onPositionChanged: mouse => {
            if (pressed)
                root.set(mouse.x / width);
        }
        onWheel: wheel => root.set(root.value + (wheel.angleDelta.y > 0 ? root.wheelStep : -root.wheelStep))
    }
}
