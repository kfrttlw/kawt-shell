import QtQuick
import qs.config

// A check box: the box, an icon if any, the words; under them one dim line of what it does.
//   Check { text: "Scanlines"; note: "faint lines over the screen"; checked: …; onToggled: … }
Item {
    id: root

    property string text: ""
    property string note: ""
    property string icon: ""
    property bool checked: false
    property bool radio: false // a round one: one of a few

    signal toggled

    implicitWidth: Math.max(row.implicitWidth, notes.visible ? 21 + notes.implicitWidth : 0)
    implicitHeight: row.implicitHeight + (notes.visible ? notes.implicitHeight : 0)

    Row {
        id: row

        spacing: 5

        PixIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.radio ? (root.checked ? "radioOn" : "radioOff") : (root.checked ? "boxOn" : "boxOff")
        }

        PixIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
        }
    }

    Label {
        id: notes

        visible: root.note !== ""
        x: 21
        y: row.height
        width: root.width > 0 ? Math.max(0, root.width - x) : implicitWidth
        wrapMode: Text.WordWrap
        text: root.note
        color: Colors.dim
    }

    MouseArea {
        anchors.fill: row
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
