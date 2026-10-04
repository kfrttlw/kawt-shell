import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The profile, big and centered over a dimmed screen (super + i).
// Same content as the [~] popover, with more room for the graphs.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("dashboard", forScreen)

    screen: forScreen
    visible: open
    color: "transparent"

    WlrLayershell.namespace: "kawt-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    onOpenChanged: if (open) {
        box.forceActiveFocus();
        fadeIn.restart();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.close()
        }
    }

    TitledBox {
        id: box

        x: Math.round((root.width - width) / 2)
        y: Math.max(Metrics.barHeight + Metrics.padding * 2, Math.round((root.height - height) / 2))
        width: Math.min(900, root.width - Metrics.padding * 4)
        height: content.implicitHeight + Metrics.padding * 3 + titleOverhang
        title: `${SysInfo.user}@${SysInfo.host}`
        hint: "esc"

        Keys.onEscapePressed: Panels.close()

        NumberAnimation {
            id: fadeIn

            target: box
            property: "opacity"
            from: 0
            to: 1
            duration: 140
        }

        MouseArea {
            anchors.fill: parent
            onClicked: box.forceActiveFocus()
        }

        ProfileContent {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding * 1.5
            anchors.topMargin: Metrics.padding * 1.5 + box.titleOverhang
            open: root.open
            forScreen: root.forScreen
            wide: true
        }
    }
}
