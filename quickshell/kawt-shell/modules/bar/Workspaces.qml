import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// The desks as raised squares with their number: the one you're on pressed in, its number red; a
// line under the number where there are windows; red where a window wants you (urgent). The wheel
// walks them (up to 10, what super + 1..0 reach, or further if there are more). A right click: how
// that desk lays out its windows (tiled, or free like KDE: Hypr.setDeskFloating), cascade them,
// bring the window in focus there. "s:name" is the special workspace (scratchpad) open here.
// With several monitors each bar lists its own: a desk living on another monitor shows in that
// monitor's bar only (clicking it here would only throw the focus over there).
Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    // (none while this monitor isn't known yet, right at the start: all of them would land here)
    readonly property list<int> elsewhere: monitor ? Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor && w.monitor.name !== monitor.name).map(w => w.id) : []
    readonly property list<int> occupied: Hyprland.workspaces.values.filter(w => w.id > 0 && !elsewhere.includes(w.id) && (w.toplevels?.values?.length ?? 1) > 0).map(w => w.id)
    readonly property int count: Math.max(5, activeId, ...occupied)
    // 1..count, without the other monitors' ones
    readonly property var shown: Array.from({ length: count }, (_, i) => i + 1).filter(id => !elsewhere.includes(id))
    readonly property list<int> urgent: Hyprland.workspaces.values.filter(w => w.id > 0 && w.urgent === true).map(w => w.id)
    // "special" (the plain scratchpad) or "special:term"; "" when none is open here
    readonly property string special: monitor?.lastIpcObject?.specialWorkspace?.name ?? ""
    readonly property int side: Metrics.barHeight - 6
    property real wheelAcc: 0
    property int menuDesk: 0

    implicitWidth: row.implicitWidth + (specialLabel.visible ? specialLabel.implicitWidth + 4 : 0)
    implicitHeight: side

    // the wheel: one desk per notch (touchpads send many small steps)
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

        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: root.shown

            Item {
                id: ws

                required property int modelData
                readonly property int wsId: modelData
                readonly property bool current: wsId === root.activeId
                readonly property bool used: root.occupied.includes(wsId)
                readonly property bool urgent: root.urgent.includes(wsId) && !current

                implicitWidth: Math.max(root.side, digit.implicitWidth + 10)
                implicitHeight: root.side

                Rectangle {
                    anchors.fill: parent
                    color: area.containsMouse && !ws.current ? Colors.mix(Colors.face, Colors.hi, 0.12) : Colors.face

                    Bevel {
                        style: ws.current || area.pressed ? "pressed" : "raised"
                    }
                }

                Label {
                    id: digit

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: ws.current ? 1 : 0
                    anchors.verticalCenterOffset: ws.current ? 0 : -1
                    text: String(ws.wsId)
                    color: ws.current || ws.urgent ? Colors.accent : Colors.fg
                }

                // there are windows there
                Rectangle {
                    visible: ws.used
                    anchors.horizontalCenter: digit.horizontalCenter
                    anchors.top: digit.baseline
                    anchors.topMargin: 2
                    width: digit.implicitWidth + 2
                    height: 1
                    color: digit.color
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton && Hypr.lua) {
                            root.menuDesk = ws.wsId;
                            menu.target = ws;
                            menu.open();
                        } else {
                            Hypr.focusWorkspace(ws.wsId);
                        }
                    }
                }

                Tip {
                    text: Strings.t("deskTip").arg(ws.wsId)
                    hovered: area.containsMouse
                }
            }
        }
    }

    BarMenu {
        id: menu

        readonly property bool floats: Hypr.floatDesks.includes(root.menuDesk)

        items: [
            { text: Strings.t("tile"), checked: !floats, action: () => Hypr.setDeskFloating(root.menuDesk, false) },
            { text: Strings.t("float"), checked: floats, action: () => Hypr.setDeskFloating(root.menuDesk, true) },
            { text: Strings.t("cascade"), action: () => {
                    Hypr.setDeskFloating(root.menuDesk, true);
                    Hypr.cascade(root.menuDesk);
                } },
            "-",
            { text: Strings.t("moveHere"), action: () => Hyprland.activeToplevel && Hypr.moveToDesk(Hyprland.activeToplevel, root.menuDesk) }
        ]
    }

    Label {
        id: specialLabel

        anchors.left: row.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        visible: root.special !== ""
        text: root.special === "special" ? "s" : `s:${root.special.replace(/^special:/, "")}`
        color: Colors.accent
    }
}
