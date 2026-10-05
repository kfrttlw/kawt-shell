import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.utils

// ┌─vol──────────────────────────┐
// │ [##############------]  70%  │
// └──────────────────────────────┘
// bottom center of the focused screen; clicks go straight through it
PanelWindow {
    id: root

    required property ShellScreen forScreen

    screen: forScreen
    visible: (Osd.shown || box.opacity > 0) && forScreen.name === Panels.focusedScreen
    color: "transparent"
    implicitWidth: Math.max(320, line.implicitWidth + Metrics.padding * 4)
    implicitHeight: box.height + box.titleOverhang + 2

    WlrLayershell.namespace: "kawt-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    anchors.bottom: true
    margins.bottom: Math.round(forScreen.height * 0.12)

    TitledBox {
        id: box

        y: titleOverhang
        width: parent.width
        height: line.implicitHeight + Metrics.padding * 2 + titleOverhang
        title: ({ br: "brightness", charge: "charging", unplug: "on battery" })[Osd.kind] ?? "volume"
        hint: Osd.muted ? "muted" : ""
        opacity: Osd.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Label {
            id: line

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Metrics.padding
            text: `[${Fmt.bar(Osd.muted ? 0 : Osd.value, 24)}] ${String(Math.round(Osd.value * 100)).padStart(3)}%` + (Osd.extra ? ` · ${Osd.extra}` : "")
            color: Osd.muted ? Colors.dim : Colors.fg
        }
    }
}
