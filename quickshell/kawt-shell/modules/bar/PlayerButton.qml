import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// the note, while some MPRIS player plays or is paused (the one services/Media.qml follows).
// A click: the player
BarIcon {
    id: root

    readonly property MprisPlayer player: Media.player

    visible: Settings.barShows("player") && player !== null
    icon: "note"
    tip: `${player?.trackTitle || player?.identity || ""}${player?.trackArtist ? " — " + player.trackArtist : ""} · ${Strings.t("music")}`
}
