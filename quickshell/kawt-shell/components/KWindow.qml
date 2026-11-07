import QtQuick
import qs.config

// A kawt window the old way: raised, a title bar (black in kawt's own themes) with an icon and
// the name, × to close, a hard shadow. What's inside goes under the title, `pad` in.
//   KWindow { title: "…"; icon: "power"; width: 400; height: chrome + body.implicitHeight; … }
Item {
    id: root

    property string title: ""
    property string icon: "logo"
    property bool focused: true
    property bool closable: true
    property int pad: 10
    readonly property int titleHeight: Metrics.fontSize + 9
    // the frame, the title and the padding: the window's height is this + its content's
    readonly property int chrome: titleHeight + 6 + 2 + pad * 2
    default property alias content: body.data

    signal closeClicked

    // the hard shadow
    Rectangle {
        x: 5
        y: 5
        width: parent.width
        height: parent.height
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.face

        Bevel {
            style: "raised"
        }
    }

    Rectangle {
        id: bar

        x: 3
        y: 3
        width: parent.width - 6
        height: root.titleHeight
        color: root.focused ? Colors.title : Colors.titleOff

        PixIcon {
            x: 3
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
        }

        Label {
            x: 23
            width: parent.width - x - 24
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.title
            color: root.focused ? Colors.titleInk : Colors.titleOffText
        }

        // ×
        Rectangle {
            visible: root.closable
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: parent.height - 4
            color: Colors.face

            Bevel {
                style: closeArea.pressed ? "pressed" : "raised"
            }

            Label {
                anchors.centerIn: parent
                text: "×"
            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeClicked()
            }
        }
    }

    Item {
        id: body

        x: 3 + root.pad
        y: bar.y + bar.height + 1 + root.pad
        width: parent.width - 6 - root.pad * 2
        height: parent.height - y - root.pad - 3
    }
}
