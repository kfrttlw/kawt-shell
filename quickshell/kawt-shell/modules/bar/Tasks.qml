import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// The windows of the workspace this screen shows, as raised buttons (the bar is a taskbar with
// raised frames, Bar.qml): its icon and its title, the one in focus pressed in, a click goes to a
// window. They share the room they get: `taskWidth` each, narrower when there are many, never
// under `minWidth` (what doesn't fit then is cut off at the right end).
// Put away (minimized) ones stay here, dim, after the others: a click brings one back. On a
// floating desk a click on the one in focus puts it away, as old systems did
Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int desk: monitor?.activeWorkspace?.id ?? 0
    readonly property bool floats: Hypr.floatDesks.includes(desk)
    readonly property var windows: [...(monitor?.activeWorkspace?.toplevels?.values ?? []), ...Hypr.awayOn(desk)]
    readonly property int gap: 3
    readonly property int taskWidth: Math.round(170 * Metrics.scale)
    readonly property int minWidth: Math.round(56 * Metrics.scale)
    readonly property int each: windows.length ? Math.max(minWidth, Math.min(taskWidth, Math.floor((width - (windows.length - 1) * gap) / windows.length))) : taskWidth

    implicitHeight: Metrics.barHeight - Metrics.spacing
    clip: true

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        Repeater {
            model: root.windows

            BarBox {
                id: task

                required property var modelData
                // the app id comes with the window itself; hyprland's class only once it was asked
                readonly property string cls: modelData.wayland?.appId || modelData.lastIpcObject?.class || ""
                readonly property bool focused: Hyprland.activeToplevel === modelData
                readonly property bool isAway: Hypr.isAway(modelData)
                readonly property int iconSize: Math.round(Metrics.fontSize * 1.2)

                width: root.each
                down: focused && !isAway
                spacing: Metrics.spacing
                onClicked: {
                    if (isAway)
                        Hypr.restore(modelData, root.desk);
                    else if (focused && root.floats)
                        Hypr.minimize(modelData);
                    else
                        Hypr.focusWindow(modelData);
                }

                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: task.iconSize
                    height: task.iconSize
                    icon: DesktopEntries.heuristicLookup(task.cls)?.icon ?? ""
                    name: task.cls || task.modelData.title || "?"
                    colored: task.focused && !task.isAway
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, task.width - Metrics.padding * 2 - task.iconSize - task.spacing)
                    elide: Text.ElideRight
                    text: task.modelData.title || task.cls
                    color: task.isAway ? Colors.dim : Colors.fg
                    font.bold: !Metrics.pixel && (task.focused && !task.isAway)
                }
            }
        }
    }
}
