import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Settings.scanlines: faint dark lines over the whole screen, every third pixel row, like an
// old picture tube's. Above everything, yet every click and key goes through it (no input
// region). Drawn once per size into one picture; screenshots get them too.
PanelWindow {
    id: root

    required property ShellScreen forScreen

    screen: forScreen
    color: "transparent"
    mask: Region {}

    WlrLayershell.namespace: "kawt-scanlines"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Canvas {
        id: lines

        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            // darker on a dark theme (the light one is paper: just a trace)
            ctx.fillStyle = Qt.rgba(0, 0, 0, Colors.light ? 0.06 : 0.18);
            for (let y = 0; y < height; y += 3)
                ctx.fillRect(0, y, width, 1);
        }

        Connections {
            target: Colors

            function onLightChanged(): void {
                lines.requestPaint();
            }
        }
    }
}
