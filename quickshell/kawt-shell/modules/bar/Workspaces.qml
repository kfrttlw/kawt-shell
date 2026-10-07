import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// [1] 2 3 4 5 [s:term]  — lazygit-style tabs for Hyprland workspaces.
// The wheel walks them; a workspace with a window that wants attention (urgent) shows in the
// warn color; [s:name] is the special workspace (scratchpad) open on this monitor.
Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property list<int> occupied: Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id)
    readonly property int count: Math.max(5, activeId, ...occupied)
    readonly property list<int> urgent: Hyprland.workspaces.values.filter(w => w.id > 0 && w.urgent === true).map(w => w.id)
    // "special" (the plain scratchpad) or "special:term"; "" when none is open here
    // (services/Hypr.qml keeps this up to date)
    readonly property string special: monitor?.lastIpcObject?.specialWorkspace?.name ?? ""
    property real wheelAcc: 0

    implicitWidth: row.implicitWidth + 4 + (specialLabel.visible ? specialLabel.implicitWidth + 4 : 0)
    implicitHeight: Metrics.barHeight - Metrics.spacing

    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        border.color: Colors.border
        border.width: Metrics.borderWidth
        radius: Metrics.radius
    }

    // the wheel: one workspace per notch (touchpads send many small steps)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            root.wheelAcc += wheel.angleDelta.y;
            while (Math.abs(root.wheelAcc) >= 120) {
                const next = root.activeId + (root.wheelAcc > 0 ? -1 : 1);
                root.wheelAcc -= root.wheelAcc > 0 ? 120 : -120;
                if (next >= 1)
                    Hypr.focusWorkspace(next);
            }
        }
    }

    Row {
        id: row

        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.count

            Item {
                id: ws

                required property int index
                readonly property int wsId: index + 1
                readonly property bool current: wsId === root.activeId
                readonly property bool used: root.occupied.includes(wsId)
                readonly property bool urgent: root.urgent.includes(wsId) && !current

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
                    color: ws.urgent ? Colors.warn : ws.current ? Colors.accent : ws.used ? Colors.fg : Colors.dim
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

    Label {
        id: specialLabel

        anchors.left: row.right
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        visible: root.special !== ""
        text: root.special === "special" ? "[s]" : `[s:${root.special.replace(/^special:/, "")}]`
        color: Colors.accent
    }
}
