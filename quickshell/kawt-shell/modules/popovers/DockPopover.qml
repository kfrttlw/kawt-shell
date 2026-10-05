import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Pinned apps under the [$] button. Pin/unpin in the launcher (ctrl+s or right click).
Popover {
    id: root

    name: "dock"
    title: "apps"
    cardWidth: 380

    Label {
        visible: Apps.pinned.length === 0
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        wrapMode: Text.Wrap
        text: "-- nothing pinned --\nopen the launcher, pick an app and press ctrl+s (or right click it)"
        color: Colors.dim
    }

    // two columns of  [icon] name  rows; a fixed width, so one pinned app doesn't stretch
    Flow {
        id: grid

        readonly property int cell: Math.floor((width - spacing) / 2)

        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: Apps.pinned.length > 0
        spacing: Metrics.spacing

        Repeater {
            model: Apps.pinned

            Rectangle {
                id: tile

                required property var modelData

                width: grid.cell
                height: Metrics.fontSize + 16
                color: tileArea.containsMouse ? Colors.hoverFill : "transparent"
                border.width: Metrics.borderWidth
                border.color: tileArea.containsMouse ? Colors.dim : Colors.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: Metrics.spacing

                    AppIcon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        icon: tile.modelData.icon
                        name: tile.modelData.name
                        colored: tileArea.containsMouse
                    }

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: tile.modelData.name.toLowerCase()
                        color: tileArea.containsMouse ? Colors.accent : Colors.fg
                    }
                }

                MouseArea {
                    id: tileArea

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            Apps.togglePin(tile.modelData);
                        } else {
                            Panels.close();
                            Apps.launch(tile.modelData);
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        BracketButton {
            label: "all apps"
            onClicked: Panels.toggle("launcher", root.forScreen)
        }

        BracketButton {
            label: "style"
            onClicked: Panels.toggle("style", root.forScreen)
        }

        BracketButton {
            label: "shot"
            onClicked: Screenshot.take("region")
        }

        BracketButton {
            label: Recorder.recording ? "stop rec" : "rec"
            textColor: Recorder.recording ? Colors.warn : Colors.fg
            onClicked: Recorder.toggle("region")
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: "rmb: unpin"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
        }
    }
}
