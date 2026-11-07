import QtQuick
import qs.config

// A slider the old way: a sunk groove, red up to the thumb, a raised thumb you drag; the wheel
// steps it. `vertical`: from the bottom up (the sound's master). `released` comes when a drag
// ends and after each wheel step, for what should only change once you let go (seeking).
// `playhead` (the player's position) only says what it is: it looks the same.
//   LevelSlider { value: sink.volume; onMoved: v => sink.volume = v }
Item {
    id: root

    property real value: 0
    property real wheelStep: 0.05
    property bool playhead: false
    property bool vertical: false
    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property int thumbLong: 18 // across the groove
    readonly property int thumbShort: 9 // along it
    readonly property real travel: (vertical ? height : width) - thumbShort
    readonly property real at: Math.round(vertical ? (1 - clamped) * travel : clamped * travel)

    signal moved(real value)
    signal released

    implicitWidth: vertical ? thumbLong + 2 : 120
    implicitHeight: vertical ? 120 : thumbLong + 2

    // don't assign `value` here: that would break the caller's binding (e.g. to the sink volume)
    function set(v: real): void {
        moved(Math.max(0, Math.min(1, v)));
    }

    function valueAt(x: real, y: real): real {
        return vertical ? 1 - (y - thumbShort / 2) / travel : (x - thumbShort / 2) / travel;
    }

    // the groove: 4 px, sunk
    Rectangle {
        id: groove

        x: root.vertical ? Math.round((root.width - 4) / 2) : Math.round(root.thumbShort / 2)
        y: root.vertical ? Math.round(root.thumbShort / 2) : Math.round((root.height - 4) / 2)
        width: root.vertical ? 4 : root.width - root.thumbShort
        height: root.vertical ? root.height - root.thumbShort : 4
        color: Colors.well

        Bevel {
            style: "sunk"
        }

        // red up to the thumb (from the bottom, standing)
        Rectangle {
            x: root.vertical ? 1 : 1
            y: root.vertical ? root.at + 1 : 1
            width: root.vertical ? 2 : Math.max(0, root.at - 1)
            height: root.vertical ? Math.max(0, groove.height - root.at - 2) : 2
            color: root.enabled ? Colors.accent : Colors.dim
        }
    }

    // the thumb
    Rectangle {
        x: root.vertical ? Math.round((root.width - root.thumbLong) / 2) : root.at
        y: root.vertical ? root.at : Math.round((root.height - root.thumbLong) / 2)
        width: root.vertical ? root.thumbLong : root.thumbShort
        height: root.vertical ? root.thumbShort : root.thumbLong
        color: Colors.face

        Bevel {
            style: area.pressed ? "pressed" : "raised"
        }
    }

    MouseArea {
        id: area

        property real wheelAcc: 0

        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => root.set(root.valueAt(mouse.x, mouse.y))
        onPositionChanged: mouse => {
            if (pressed)
                root.set(root.valueAt(mouse.x, mouse.y));
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
