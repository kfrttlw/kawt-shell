import QtQuick
import qs.config

// A small raised button with a triangle of whole pixels: ◄ ► ▲ ▼ (the calendar's months)
//   ArrowButton { dir: "left"; onClicked: … }
BarBox {
    id: root

    property string dir: "right" // "left" | "right" | "up" | "down"
    readonly property bool across: dir === "left" || dir === "right"

    plain: false
    implicitWidth: Metrics.fontSize + 11
    implicitHeight: Metrics.fontSize + 11

    Item {
        width: root.across ? 4 : 7
        height: root.across ? 7 : 4

        // 7, 5, 3, 1 pixels, pointing where it goes
        Repeater {
            model: 4

            Rectangle {
                required property int index
                readonly property int k: root.dir === "left" || root.dir === "up" ? 3 - index : index

                x: root.across ? k : index
                y: root.across ? index : k
                width: root.across ? 1 : 7 - index * 2
                height: root.across ? 7 - index * 2 : 1
                color: Colors.fg
            }
        }
    }
}
