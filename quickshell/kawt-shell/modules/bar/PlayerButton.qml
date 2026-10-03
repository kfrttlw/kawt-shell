import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.components

// [> ▂▅▃▇▂]  — shown only while some MPRIS player exists
BarBox {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null

    visible: player !== null
    spacing: 4

    Label {
        text: "["
        color: Colors.dim
    }

    Label {
        text: root.player?.isPlaying ? ">" : "="
    }

    Visualizer {
        anchors.verticalCenter: parent.verticalCenter
        active: root.player?.isPlaying ?? false
    }

    Label {
        text: "]"
        color: Colors.dim
    }
}
