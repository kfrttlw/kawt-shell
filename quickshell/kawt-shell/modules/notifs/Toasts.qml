import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Toast stack on the right of the focused screen: under the bar, or over the tray when the bar is
// at the bottom (the newest nearest to it); beside the AI panel if it's open.
// The window is only as tall as the stack, so it doesn't block clicks below.
PanelWindow {
    id: root

    required property ShellScreen forScreen

    screen: forScreen
    visible: true // made only while there are toasts for this screen (Bar.qml)
    color: "transparent"
    implicitWidth: Metrics.toastWidth
    implicitHeight: Math.max(1, stack.implicitHeight)

    WlrLayershell.namespace: "kawt-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top: !Metrics.barBottom
    anchors.bottom: Metrics.barBottom
    anchors.right: true
    margins.top: Metrics.topGap + Metrics.spacing
    margins.bottom: Metrics.bottomGap + Metrics.spacing
    // step aside for the ai panel when it's open on this side
    margins.right: Metrics.padding + (Panels.isSidebarOpen(forScreen) && Settings.aiSide !== "left" ? (Settings.aiWide ? Math.round(forScreen.width * 0.62) : Metrics.sidebarWidth) : 0)

    Column {
        id: stack

        width: parent.width
        spacing: Metrics.spacing

        // ScriptModel: a new toast leaves the others alone. With a plain array every toast was
        // made again on each new one, and their timers started over: none went away while
        // messages kept coming
        Repeater {
            model: ScriptModel {
                values: Metrics.barBottom ? Notifs.popups.slice().reverse() : Notifs.popups
            }

            Toast {
                width: stack.width
            }
        }
    }
}
