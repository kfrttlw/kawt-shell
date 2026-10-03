import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Pinned apps under the [$] button. Pin/unpin in the launcher (ctrl+s or right click).
Popover {
    id: root

    readonly property int columns: 4

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

    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: Apps.pinned.length > 0
        columns: root.columns
        rowSpacing: Metrics.spacing
        columnSpacing: Metrics.spacing

        Repeater {
            model: Apps.pinned

            Rectangle {
                id: tile

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1 // equal columns
                implicitHeight: tileCol.implicitHeight + Metrics.padding * 2
                color: tileArea.containsMouse ? Colors.hoverFill : "transparent"
                border.width: Metrics.borderWidth
                border.color: tileArea.containsMouse ? Colors.dim : Colors.border

                Column {
                    id: tileCol

                    anchors.centerIn: parent
                    width: parent.width - Metrics.padding
                    spacing: 4

                    AppIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 32
                        height: 32
                        icon: tile.modelData.icon
                        name: tile.modelData.name
                        colored: tileArea.containsMouse
                    }

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: tile.modelData.name.toLowerCase()
                        color: tileArea.containsMouse ? Colors.accent : Colors.fg
                        font.pixelSize: Metrics.fontSize - 2
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

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: "rmb: unpin"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
        }
    }
}
