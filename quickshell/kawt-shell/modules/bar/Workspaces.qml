import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// [1] 2 3 4 5  — lazygit-style tabs for Hyprland workspaces
Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property list<int> occupied: Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id)
    readonly property int count: Math.max(5, activeId, ...occupied)

    implicitWidth: row.implicitWidth + 4
    implicitHeight: Metrics.barHeight - Metrics.spacing

    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        border.color: Colors.border
        border.width: Metrics.borderWidth
        radius: Metrics.radius
    }

    Row {
        id: row

        anchors.centerIn: parent

        Repeater {
            model: root.count

            Item {
                id: ws

                required property int index
                readonly property int wsId: index + 1
                readonly property bool current: wsId === root.activeId
                readonly property bool used: root.occupied.includes(wsId)

                implicitWidth: text.implicitWidth + 2
                implicitHeight: root.implicitHeight - 6

                Rectangle {
                    anchors.fill: parent
                    visible: ws.current || area.containsMouse
                    color: Colors.hoverFill
                }

                Label {
                    id: text

                    anchors.centerIn: parent
                    text: ws.current ? `[${ws.wsId}]` : ` ${ws.wsId} `
                    color: ws.current ? Colors.accent : ws.used ? Colors.fg : Colors.dim
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.focusWorkspace(ws.wsId)
                }
            }
        }
    }
}
