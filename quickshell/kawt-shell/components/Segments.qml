import QtQuick
import qs.config

// How far along, the old way: a sunk well with red blocks filling it from the left, whole
// blocks only (the focus round, the shutdown countdown).
//   Segments { width: 150; value: Focus.progress }
Rectangle {
    id: root

    property real value: 0 // 0..1
    property color fill: Colors.accent
    readonly property int count: Math.max(1, Math.floor((width - 4) / 10))

    implicitWidth: 150
    implicitHeight: 18
    color: Colors.well

    Bevel {
        style: "sunk"
    }

    Row {
        x: 3
        y: 3
        spacing: 2

        Repeater {
            model: Math.round(Math.max(0, Math.min(1, root.value)) * root.count)

            Rectangle {
                width: 8
                height: root.height - 6
                color: root.fill
            }
        }
    }
}
