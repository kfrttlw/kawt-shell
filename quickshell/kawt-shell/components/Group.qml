import QtQuick
import QtQuick.Layouts
import qs.config

// A box of settings with its name in a gap of the frame, as old systems' group boxes had.
// What's inside is laid out in a column.
Item {
    id: root

    property string title: ""
    property int spacing: 6
    default property alias content: column.data

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + name.implicitHeight + 14

    Item {
        anchors.fill: parent
        anchors.topMargin: Math.round(name.implicitHeight / 2)

        Bevel {
            style: "etched"
        }
    }

    Rectangle {
        x: 8
        width: name.implicitWidth + 6
        height: name.implicitHeight
        color: Colors.face

        Label {
            id: name

            x: 3
            text: root.title
        }
    }

    ColumnLayout {
        id: column

        x: 10
        y: name.implicitHeight + 4
        width: parent.width - 20
        spacing: root.spacing
    }
}
