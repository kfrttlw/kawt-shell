import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// [1] 2 3 4 5 [s:term]  — lazygit-style tabs for Hyprland workspaces.
// The wheel walks them (up to 10, what super + 1..0 reach, or further if there are more); a
// workspace with a window that wants attention (urgent) shows in the warn color; [s:name] is
// the special workspace (scratchpad) open on this monitor.
// With several monitors each bar lists its own: a workspace living on another monitor shows
// in that monitor's bar only (clicking it here would only throw the focus over there).
Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    // (none while this monitor isn't known yet, right at the start: all of them would land here)
    readonly property list<int> elsewhere: monitor ? Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor && w.monitor.name !== monitor.name).map(w => w.id) : []
    readonly property list<int> occupied: Hyprland.workspaces.values.filter(w => w.id > 0 && !elsewhere.includes(w.id)).map(w => w.id)
    readonly property int count: Math.max(5, activeId, ...occupied)
    // 1..count, without the other monitors' ones
    readonly property var shown: Array.from({ length: count }, (_, i) => i + 1).filter(id => !elsewhere.includes(id))
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
            let cur = root.activeId; // activeId only follows once Hyprland has switched
            while (Math.abs(root.wheelAcc) >= 120) {
                const dir = root.wheelAcc > 0 ? -1 : 1;
                root.wheelAcc += dir * 120;
                let next = cur + dir;
                while (root.elsewhere.includes(next))
                    next += dir;
                if (next >= 1 && next <= Math.max(10, root.count)) {
                    Hypr.focusWorkspace(next);
                    cur = next;
                }
            }
        }
    }

    Row {
        id: row

        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.shown

            Item {
                id: ws

                required property int modelData
                readonly property int wsId: modelData
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
