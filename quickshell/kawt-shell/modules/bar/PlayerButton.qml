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

    Bracket {
        look: root.active ? "on" : ""
    }

    Label {
        text: root.player?.isPlaying ? ">" : "="
        color: Colors.accent
    }

    // not on an old machine (cfg -> look -> old machine)
    Visualizer {
        visible: !Settings.lite
        anchors.verticalCenter: parent.verticalCenter
        active: (root.player?.isPlaying ?? false) && !Settings.lite
    }

    Bracket {
        closing: true
        look: root.active ? "on" : ""
    }
}
