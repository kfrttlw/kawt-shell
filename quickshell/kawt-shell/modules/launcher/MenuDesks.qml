import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// The start menu's desks: every workspace of this screen as a little screen with the wallpaper
// and its windows where they are (a click goes there, a window dragged onto another desk moves
// there), how the one you're on lays out its windows (tiled, or floating like KDE's), then its
// windows (a click goes to one; one dragged onto a desk above moves there). Where windows sit is
// hyprland's ipc data, asked for again every two seconds while this is shown.
ColumnLayout {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    // the same ones as the bar's squares (modules/bar/Workspaces.qml): 1..5, more while used
    readonly property list<int> elsewhere: monitor ? Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor && w.monitor.name !== monitor.name).map(w => w.id) : []
    readonly property list<int> occupied: Hyprland.workspaces.values.filter(w => w.id > 0 && !elsewhere.includes(w.id)).map(w => w.id)
    readonly property var shown: Array.from({ length: Math.max(5, activeId, ...occupied) }, (_, i) => i + 1).filter(id => !elsewhere.includes(id)).slice(0, 9)
    // and the ones put away from it (minimized), after them
    readonly property var here: [...(monitor?.activeWorkspace?.toplevels?.values ?? []), ...Hypr.awayOn(activeId)]
    readonly property bool floats: Hypr.floatDesks.includes(activeId)
    readonly property string wallpaper: Settings.wallpaper.startsWith("~/") ? Quickshell.env("HOME") + Settings.wallpaper.slice(1) : Settings.wallpaper
    readonly property int columns: 3
    readonly property real miniW: Math.floor((width - (columns - 1) * Metrics.spacing) / columns)
    readonly property real k: miniW / Math.max(1, screen.width) // screen to little screen
    property var carried: null // a window on its way to another desk
    property point carriedAt
    readonly property int dropOn: carried !== null ? deskAt(root, carriedAt.x, carriedAt.y) : 0 // the desk it would land on

    // the desk under a point of `item`; 0: none
    function deskAt(item: Item, x: real, y: real): int {
        const p = item.mapToItem(grid, x, y);
        return grid.childAt(p.x, p.y)?.modelData ?? 0;
    }

    function drop(item: Item, x: real, y: real): void {
        const id = deskAt(item, x, y), w = carried;
        carried = null;
        if (id > 0 && w && w.workspace?.id !== id)
            Hypr.moveToDesk(w, id);
    }

    spacing: Metrics.spacing

    Component.onCompleted: Hypr.refreshWindows()

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: Hypr.refreshWindows()
    }

    Grid {
        id: grid

        Layout.fillWidth: true
        columns: root.columns
        spacing: Metrics.spacing

        Repeater {
            model: root.shown

            Well {
                id: desk

                required property int modelData
                readonly property bool current: modelData === root.activeId

                width: root.miniW
                height: Math.round(root.miniW * root.screen.height / Math.max(1, root.screen.width))
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: root.wallpaper !== ""
                    source: root.wallpaper ? `file://${root.wallpaper}` : ""
                    sourceSize.width: 192
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 0.8
                }

                // its windows, where hyprland has them
                Item {
                    id: wins

                    anchors.fill: parent

                    Repeater {
                        model: Hyprland.toplevels.values.filter(t => t.workspace?.id === desk.modelData)

                        Rectangle {
                            required property var modelData
                            readonly property var at: modelData.lastIpcObject?.at ?? [0, 0]
                            readonly property var size: modelData.lastIpcObject?.size ?? [0, 0]

                            visible: size[0] > 0
                            opacity: root.carried === modelData ? 0.4 : 1
                            x: Math.round((at[0] - (root.monitor?.x ?? 0)) * root.k)
                            y: Math.round((at[1] - (root.monitor?.y ?? 0)) * root.k)
                            width: Math.max(3, Math.round(size[0] * root.k))
                            height: Math.max(3, Math.round(size[1] * root.k))
                            color: Colors.bg
                            border.width: 1
                            border.color: Hyprland.activeToplevel === modelData ? Colors.accent : Colors.border
                        }
                    }
                }

                Label {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 3
                    visible: Hypr.floatDesks.includes(desk.modelData)
                    text: "float"
                    color: Colors.fg
                    font.pixelSize: Metrics.fontSize - 3
                    style: Text.Outline
                    styleColor: Colors.bg
                }

                Label {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 3
                    text: desk.modelData
                    color: desk.current ? Colors.accent : Colors.fg
                    font.bold: true
                    font.pixelSize: Metrics.fontSize - 2
                    style: Text.Outline
                    styleColor: Colors.bg
                }

                // the one you're on, framed in the light; a window carried over it: dim
                Rectangle {
                    anchors.fill: parent
                    visible: desk.current || deskArea.containsMouse || root.carried !== null
                    color: "transparent"
                    border.width: 2
                    border.color: desk.current ? Colors.accent : root.dropOn === desk.modelData ? Colors.fg : Colors.dim
                }

                // a click goes to the desk; a window dragged from here to another desk moves there
                MouseArea {
                    id: deskArea

                    property var picked: null
                    property point from

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.carried ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    preventStealing: true
                    onPressed: m => {
                        picked = wins.childAt(m.x, m.y)?.modelData ?? null;
                        from = Qt.point(m.x, m.y);
                    }
                    onPositionChanged: m => {
                        if (!pressed || !picked)
                            return;
                        if (!root.carried && Math.hypot(m.x - from.x, m.y - from.y) > 6)
                            root.carried = picked;
                        if (root.carried)
                            root.carriedAt = deskArea.mapToItem(root, m.x, m.y);
                    }
                    onReleased: m => {
                        if (root.carried)
                            root.drop(deskArea, m.x, m.y);
                        else if (containsMouse)
                            Hypr.focusWorkspace(desk.modelData);
                        picked = null;
                    }
                    onCanceled: {
                        root.carried = null;
                        picked = null;
                    }
                }
            }
        }
    }

    // desk 3: [tiled] [floating] [cascade]
    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            Layout.fillWidth: true
            text: `on desk ${root.activeId}`
            color: Colors.dim
        }

        BracketButton {
            visible: Hypr.lua
            label: "tiled"
            textColor: root.floats ? Colors.fg : Colors.accent
            onClicked: Hypr.setDeskFloating(root.activeId, false)
        }

        BracketButton {
            visible: Hypr.lua
            label: "floating"
            textColor: root.floats ? Colors.accent : Colors.fg
            onClicked: Hypr.setDeskFloating(root.activeId, true)
        }

        BracketButton {
            visible: Hypr.lua && root.floats
            label: "cascade"
            onClicked: Hypr.cascade(root.activeId)
        }
    }

    Well {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Column {
            anchors.fill: parent
            anchors.margins: 3
            clip: true

            Repeater {
                model: root.here

                Item {
                    id: win

                    required property var modelData
                    readonly property string cls: modelData.wayland?.appId || modelData.lastIpcObject?.class || ""
                    readonly property bool focused: Hyprland.activeToplevel === modelData
                    readonly property bool isAway: Hypr.isAway(modelData)

                    width: parent.width
                    height: Metrics.fontSize + 10

                    Rectangle {
                        anchors.fill: parent
                        visible: win.focused || area.containsMouse
                        color: win.focused && Colors.bevel ? Colors.accent : Colors.hoverFill
                    }

                    AppIcon {
                        id: icon

                        x: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(Metrics.fontSize * 1.2)
                        height: width
                        icon: DesktopEntries.heuristicLookup(win.cls)?.icon ?? ""
                        name: win.cls || win.modelData.title || "?"
                        colored: win.focused
                    }

                    Label {
                        anchors.left: icon.right
                        anchors.leftMargin: Metrics.spacing
                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: (win.isAway ? "(put away) " : "") + (win.modelData.title || win.cls)
                        color: win.focused && Colors.bevel ? Colors.onAccent : win.isAway ? Colors.dim : Colors.fg
                    }

                    // a click goes to it (one put away comes back); dragged onto a desk above, it moves there
                    MouseArea {
                        id: area

                        property point from

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.carried ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        preventStealing: true
                        onPressed: m => from = Qt.point(m.x, m.y)
                        onPositionChanged: m => {
                            if (!pressed)
                                return;
                            if (!root.carried && Math.hypot(m.x - from.x, m.y - from.y) > 6)
                                root.carried = win.modelData;
                            if (root.carried)
                                root.carriedAt = area.mapToItem(root, m.x, m.y);
                        }
                        onReleased: m => {
                            if (root.carried) {
                                root.drop(area, m.x, m.y);
                            } else if (containsMouse) {
                                Hypr.focusWindow(win.modelData);
                                Panels.close();
                            }
                        }
                        onCanceled: root.carried = null
                    }
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: root.here.length === 0
            text: "an empty desk"
            color: Colors.dim
        }

        // the window being carried, under the pointer (here: drawn over the desks above)
        Rectangle {
            readonly property point at: parent.mapFromItem(root, root.carriedAt.x, root.carriedAt.y)

            visible: root.carried !== null
            z: 10
            x: Math.round(at.x - width / 2)
            y: Math.round(at.y - height / 2)
            width: carriedName.implicitWidth + Metrics.padding * 2
            height: carriedName.implicitHeight + 6
            color: Colors.face
            border.width: 1
            border.color: Colors.accent

            Label {
                id: carriedName

                anchors.centerIn: parent
                text: root.carried?.wayland?.appId || root.carried?.lastIpcObject?.class || root.carried?.title || "?"
            }
        }
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: "a click goes to a desk or a window · drag a window onto a desk: it moves there"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }
}
