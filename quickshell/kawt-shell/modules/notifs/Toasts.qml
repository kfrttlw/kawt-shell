import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Toast stack in the top-right corner of the focused screen, next to the AI panel if it's open.
// The window is only as tall as the stack, so it doesn't block clicks below.
PanelWindow {
    id: root

    required property ShellScreen forScreen

    screen: forScreen
    visible: forScreen.name === Panels.focusedScreen && Notifs.popups.length > 0 && !Panels.isOpen("notifs", forScreen)
    color: "transparent"
    implicitWidth: Metrics.toastWidth
    implicitHeight: Math.max(1, stack.implicitHeight)

    WlrLayershell.namespace: "kawt-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    anchors.right: true
    margins.top: Metrics.barHeight + Metrics.spacing
    margins.right: Metrics.padding + (Panels.isSidebarOpen(forScreen) ? Metrics.sidebarWidth : 0)

    Column {
        id: stack

        width: parent.width
        spacing: Metrics.spacing

        Repeater {
            model: Notifs.popups

            Toast {
                width: stack.width
            }
        }
    }
}
