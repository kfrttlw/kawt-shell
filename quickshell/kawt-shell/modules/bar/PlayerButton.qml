import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// [> ▂▅▃▇▂]  — shown only while some MPRIS player exists (the one services/Media.qml follows)
BarBox {
    id: root

    readonly property MprisPlayer player: Media.player

    visible: Settings.barShows("player") && (player !== null)
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
