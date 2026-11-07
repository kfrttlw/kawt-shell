import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import "../../utils/pixicons.js" as Pix

// ┌───────────────────────────────────────┐
// │ ◄)  Sound   ▮▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯   70%   │
// └───────────────────────────────────────┘
// A raised plate at the bottom center of the focused screen: the sound, the brightness, the
// charger in or out. Clicks go straight through it.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool battery: Osd.kind === "charge" || Osd.kind === "unplug"

    screen: forScreen
    visible: true // made only while the osd shows, kept a moment for the fade-out (Bar.qml)
    color: "transparent"
    implicitWidth: plate.width + 5
    implicitHeight: plate.height + 5

    WlrLayershell.namespace: "kawt-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    anchors.bottom: true
    margins.bottom: Math.round(forScreen.height * 0.12)

    Item {
        id: plate

        width: row.implicitWidth + 24
        height: Metrics.fontSize + 26
        opacity: Osd.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        // the hard shadow
        Rectangle {
            x: 5
            y: 5
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0.5)
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.face

            Bevel {
                style: "raised"
            }
        }

        Row {
            id: row

            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            PixIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: Osd.kind === "br" ? "sun" : root.battery ? Pix.battery(Osd.value, Osd.kind === "charge") : Pix.volume(Osd.value, Osd.muted)
            }

            Label {
                width: Math.round(Metrics.fontSize * 0.6 * 9)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: Strings.t(({ br: "brightness", charge: "osdCharging", unplug: "osdOnBattery" })[Osd.kind] ?? (Osd.muted ? "osdMuted" : "sound"))
            }

            Segments {
                width: Math.round(170 * Metrics.scale)
                anchors.verticalCenter: parent.verticalCenter
                value: Osd.muted ? 0 : Osd.value
            }

            Label {
                id: pct

                width: Math.round(Metrics.fontSize * 0.6 * 4)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(Osd.value * 100)}%`
                color: Osd.muted ? Colors.dim : Colors.fg
            }

            // "1h 10m to full"
            Label {
                id: extra

                visible: Osd.extra !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: Osd.extra
                color: Colors.dim
            }
        }
    }
}
