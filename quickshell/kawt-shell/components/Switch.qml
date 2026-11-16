import QtQuick
import qs.config

// A switch: a sunk slot with a raised knob in it, on the left while off; a click and it slides
// to the right, the slot lit in the accent: on. The words beside it, a dim line of what it does
// under them. The same as a Check otherwise:
//   Switch { text: "In the theme's tones"; checked: …; onToggled: … }
Item {
    id: root

    property string text: ""
    property string note: ""
    property bool checked: false

    signal toggled

    readonly property int slotH: Metrics.fontSize + 5
    readonly property int slotW: slotH * 2

    implicitWidth: Math.max(row.implicitWidth, notes.visible ? slotW + 6 + notes.implicitWidth : 0)
    implicitHeight: row.implicitHeight + (notes.visible ? notes.implicitHeight : 0)

    Row {
        id: row

        spacing: 6

        // the slot, sunk; lit while on
        Rectangle {
            id: slot

            anchors.verticalCenter: parent.verticalCenter
            width: root.slotW
            height: root.slotH
            color: root.checked ? Colors.accent : Colors.well

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Bevel {
                style: "sunk"
            }

            // the knob, raised, a square; slides across
            Rectangle {
                x: root.checked ? slot.width - width - 2 : 2
                y: 2
                width: slot.height - 4
                height: width
                color: Colors.face

                Behavior on x {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutQuad
                    }
                }

                Bevel {
                    style: "raised"
                }
            }
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
        }
    }

    Label {
        id: notes

        visible: root.note !== ""
        x: root.slotW + 6
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
