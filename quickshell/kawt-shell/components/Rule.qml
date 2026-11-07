import QtQuick
import qs.config

// ─── a line between parts of a panel: thin, in the line color; with raised frames a groove (a
// dark line beside a light one), as old systems drew it. `vertical`: one between columns.
Item {
    id: root

    property bool vertical: false
    readonly property int thick: 2

    implicitWidth: vertical ? thick : 0
    implicitHeight: vertical ? 0 : thick

    Rectangle {
        width: root.vertical ? 1 : parent.width
        height: root.vertical ? parent.height : 1
        color: Colors.lo
    }

    Rectangle {
        x: root.vertical ? 1 : 0
        y: root.vertical ? 0 : 1
        width: root.vertical ? 1 : parent.width
        height: root.vertical ? parent.height : 1
        color: Colors.hi
    }
}
