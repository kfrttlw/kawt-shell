import QtQuick
import qs.config

// ▮▮▮▮▮▮▯▯▯▯ a level in segments, like the bar's (components/Meter.qml), that you can drag or
// scroll: lit ones in the text color, the rest in the line color. playhead: the last lit one
// red (the player's position). `released` comes when a drag ends and after each wheel step,
// for what should only change once you let go (seeking)
Item {
    id: root

    property real value: 0
    property real wheelStep: 0.05
    property bool playhead: false
    readonly property int segWidth: Math.max(3, Math.round(Metrics.fontSize * 0.3))
    readonly property int segGap: Math.max(1, Math.round(Metrics.fontSize / 7))
    readonly property int segCount: Math.max(1, Math.floor((width + segGap) / (segWidth + segGap)))
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * segCount)

    signal moved(real value)
    signal released

    implicitHeight: Math.round(Metrics.fontSize * 0.8)

    // don't assign `value` here: that would break the caller's binding (e.g. to the sink volume)
    function set(v: real): void {
        moved(Math.max(0, Math.min(1, v)));
    }

    Row {
        anchors.fill: parent
        spacing: root.segGap

        Repeater {
            model: root.segCount

            Rectangle {
                required property int index

                width: root.segWidth
                height: parent.height
                color: root.playhead && index === Math.max(0, root.lit - 1) ? Colors.accent : index < root.lit ? Colors.fg : Colors.border
            }
        }
    }

    MouseArea {
        property real wheelAcc: 0

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => root.set(mouse.x / width)
        onPositionChanged: mouse => {
            if (pressed)
                root.set(mouse.x / width);
        }
        onReleased: root.released()
        // a step per notch (touchpads send many small deltas: they add up to one)
        onWheel: wheel => {
            wheelAcc += wheel.angleDelta.y;
            let steps = 0;
            while (Math.abs(wheelAcc) >= 120) {
                steps += wheelAcc > 0 ? 1 : -1;
                wheelAcc -= Math.sign(wheelAcc) * 120;
            }
            if (steps !== 0) {
                root.set(root.value + steps * root.wheelStep);
                root.released();
            }
        }
    }
}
