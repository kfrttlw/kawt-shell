import QtQuick
import qs.config

// A kawt window the old way: raised, a title bar (black in kawt's own themes) with an icon and
// the name, _ □ × on the right, a hard shadow, and under it all a status bar of sunk cells if
// it has one. What's inside goes under the title, `pad` in.
//   KWindow { title: "…"; icon: "power"; width: 400; height: chrome + body.implicitHeight; … }
//   status: ["2 of 5 done", "focus: 3 rounds"]: the cells, the last one takes what's left
Item {
    id: root

    property string title: ""
    property string icon: "logo"
    property bool focused: true
    property bool urgent: false // a red title (an urgent message)
    property bool closable: true
    property bool minimizable: false
    property bool maximizable: false
    property bool maximized: false // □ draws two windows then
    property bool shadow: true
    property int pad: 10
    property var status: []
    readonly property int titleHeight: Metrics.fontSize + 9
    readonly property int statusHeight: status.length > 0 ? Metrics.fontSize + 9 : 0
    // the frame, the title, the status bar and the padding: the window's height is this + its content's
    readonly property int chrome: titleHeight + 6 + 2 + pad * 2 + statusHeight
    default property alias content: body.data

    signal closeClicked
    signal minimizeClicked
    signal maximizeClicked
    signal titlePressed // a real window starts moving with the pointer here
    signal titleDoubleClicked

    // one of the title's buttons: × _ □, a drawing of whole pixels each
    component TitleButton: Rectangle {
        id: button

        property string kind: "close"

        signal clicked

        width: 16
        height: root.titleHeight - 4
        color: Colors.face

        Bevel {
            style: buttonArea.pressed ? "pressed" : "raised"
        }

        Item {
            x: Math.round((parent.width - 8) / 2) + (buttonArea.pressed ? 1 : 0)
            y: Math.round((parent.height - 7) / 2) + (buttonArea.pressed ? 1 : 0)
            width: 8
            height: 7

            // ×: two diagonals, two pixels thick
            Repeater {
                model: button.kind === "close" ? 7 : 0

                Item {
                    id: stroke

                    required property int index

                    Rectangle {
                        x: stroke.index
                        y: stroke.index
                        width: 2
                        height: 1
                        color: Colors.fg
                    }

                    Rectangle {
                        x: 6 - stroke.index
                        y: stroke.index
                        width: 2
                        height: 1
                        color: Colors.fg
                    }
                }
            }

            // _: a line at the bottom
            Rectangle {
                visible: button.kind === "min"
                x: 1
                y: 5
                width: 6
                height: 2
                color: Colors.fg
            }

            // □: a window with a thick top; two of them when it's maximized
            Rectangle {
                visible: button.kind === "max" && !root.maximized
                width: 8
                height: 7
                color: "transparent"
                border.color: Colors.fg
                border.width: 1

                Rectangle {
                    width: parent.width
                    height: 2
                    color: Colors.fg
                }
            }

            Repeater {
                model: button.kind === "max" && root.maximized ? [[2, 0], [0, 2]] : []

                Rectangle {
                    id: pane

                    required property var modelData

                    x: pane.modelData[0]
                    y: pane.modelData[1]
                    width: 6
                    height: 5
                    color: Colors.face
                    border.color: Colors.fg
                    border.width: 1

                    Rectangle {
                        width: parent.width
                        height: 2
                        color: Colors.fg
                    }
                }
            }
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // the hard shadow
    Rectangle {
        visible: root.shadow
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
        color: root.urgent ? Colors.accent : root.focused ? Colors.title : Colors.titleOff

        // pressed on the title: a real window moves with the pointer (AppWindow), twice: □
        MouseArea {
            anchors.fill: parent
            onPressed: root.titlePressed()
            onDoubleClicked: root.titleDoubleClicked()
        }

        PixIcon {
            x: 3
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
        }

        Label {
            x: 23
            width: buttons.x - x - 4
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.title
            color: root.urgent ? Colors.onAccent : root.focused ? Colors.titleInk : Colors.titleOffText
        }

        Row {
            id: buttons

            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter

            TitleButton {
                visible: root.minimizable
                kind: "min"
                onClicked: root.minimizeClicked()
            }

            TitleButton {
                visible: root.maximizable
                kind: "max"
                onClicked: root.maximizeClicked()
            }

            // a gap before ×, as old systems had
            Item {
                visible: root.closable && (root.minimizable || root.maximizable)
                width: 2
                height: 1
            }

            TitleButton {
                visible: root.closable
                kind: "close"
                onClicked: root.closeClicked()
            }
        }
    }

    Item {
        id: body

        clip: true // what doesn't fit stays inside the frame
        x: 3 + root.pad
        y: bar.y + bar.height + 1 + root.pad
        width: parent.width - 6 - root.pad * 2
        height: parent.height - y - root.pad - 3 - root.statusHeight
    }

    // the status bar: sunk cells side by side, the last one to the end
    Row {
        visible: root.status.length > 0
        x: 3
        y: parent.height - 3 - root.statusHeight + 2
        width: parent.width - 6
        height: root.statusHeight - 2
        spacing: 2

        Repeater {
            model: root.status

            Item {
                id: cell

                required property var modelData
                required property int index
                readonly property bool last: index === root.status.length - 1

                width: last ? parent.width - x : Math.max(words.implicitWidth + 12, Math.round(parent.width / (root.status.length + 0.5)))
                height: parent.height

                Bevel {
                    style: "well"
                }

                Label {
                    id: words

                    x: 5
                    width: parent.width - 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: cell.modelData
                }
            }
        }
    }
}
