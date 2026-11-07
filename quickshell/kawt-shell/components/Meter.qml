import QtQuick
import qs.config

// ▮▮▮▯▯ a level in a few segments, like an old stereo's: lit ones in the text color, the rest
// in the line color. value 0..1 (more than 1, all lit)
Row {
    id: root

    property real value: 0
    property int count: 5
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * count)

    spacing: Math.max(1, Math.round(Metrics.fontSize / 7))

    Repeater {
        model: root.count

        Rectangle {
            required property int index

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(2, Math.round(Metrics.fontSize * 0.3))
            height: Math.round(Metrics.fontSize * 0.7)
            color: index < root.lit ? Colors.fg : Colors.border
        }
    }
}
