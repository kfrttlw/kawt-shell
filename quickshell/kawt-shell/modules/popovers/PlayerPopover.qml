import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.utils

Popover {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool hasLength: (player?.lengthSupported ?? false) && player.length > 0
    readonly property int barWidth: 20

    name: "player"
    title: root.player?.identity?.toLowerCase() || "player"
    cardWidth: 300

    // MPRIS doesn't push position updates; poll while visible
    Timer {
        running: root.open && (root.player?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: root.player?.trackTitle || "no media"
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        visible: text !== ""
        text: [root.player?.trackArtist, root.player?.trackAlbum].filter(s => s).join(" — ")
        color: Colors.dim
    }

    Label {
        visible: root.hasLength
        Layout.fillWidth: true
        text: `${Fmt.mmss(root.player?.position)} [${Fmt.bar(root.player?.position / root.player?.length, root.barWidth)}] ${Fmt.mmss(root.player?.length)}`
        color: Colors.dim

        MouseArea {
            // click inside the [####----] part to seek
            anchors.fill: parent
            enabled: root.player?.canSeek ?? false
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                const cw = parent.contentWidth / parent.text.length;
                const start = parent.text.indexOf("[") + 1;
                const frac = (mouse.x / cw - start) / root.barWidth;
                if (frac >= 0 && frac <= 1)
                    root.player.position = frac * root.player.length;
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Metrics.spacing

        BracketButton {
            label: "<<"
            onClicked: root.player?.previous()
        }

        BracketButton {
            label: root.player?.isPlaying ? "||" : ">"
            onClicked: root.player?.togglePlaying()
        }

        BracketButton {
            label: ">>"
            onClicked: root.player?.next()
        }
    }
}
