import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// A grip, then the pinned apps (the start menu pins them: services/Apps.qml) as icons, no words.
// A click starts one, a right click unpins it. Off in the settings, or with nothing pinned
Row {
    id: root

    property int most: 4

    visible: Settings.barShows("quick") && Apps.pinned.length > 0
    spacing: 1

    // the grip: a raised line, as old toolbars had
    Item {
        width: 6
        height: Metrics.barHeight - 8
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            x: 2
            width: 3
            height: parent.height
            color: Colors.face

            Bevel {
                style: "bump"
            }
        }
    }

    Repeater {
        model: Apps.pinned.slice(0, root.most)

        Item {
            id: app

            required property var modelData

            width: Metrics.barHeight - 6
            height: Metrics.barHeight - 8
            anchors.verticalCenter: parent.verticalCenter

            Bevel {
                visible: area.containsMouse
                style: area.pressed ? "well" : "bump"
            }

            AppIcon {
                anchors.centerIn: parent
                width: 16
                height: 16
                icon: app.modelData.icon ?? ""
                name: app.modelData.name ?? "?"
                colored: true
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        menu.open();
                    else
                        Apps.launch(app.modelData);
                }
            }

            Tip {
                text: app.modelData.name ?? ""
                hovered: area.containsMouse
            }

            BarMenu {
                id: menu

                items: [{ text: Strings.t("unpin"), action: () => Apps.togglePin(app.modelData) }]
            }
        }
    }
}
