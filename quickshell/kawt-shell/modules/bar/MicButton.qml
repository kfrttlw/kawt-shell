import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// [mic on] · [mic ●] some app is recording (accent) · [mic off] muted
// click: the mic panel (apps, per-app mute), scroll: mic volume
BarIcon {
    id: root

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: !!source?.audio?.muted
    // apps recording right now: pipewire calls them "Stream/Input/Audio"
    readonly property int recording: Pipewire.nodes.values.filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Audio").length

    // only while some app listens, red; or while it's muted
    visible: Settings.barShows("mic") && source !== null && (recording > 0 || muted || Settings.micAlways)
    icon: "mic"
    ink: recording > 0 && !muted ? Colors.accent : "transparent"
    text: muted ? "off" : ""
    textColor: Colors.dim
    tip: muted ? `${Strings.t("mic")}: off` : Strings.t("mic")

    onScrolled: steps => {
        if (source?.audio)
            source.audio.volume = Math.max(0, Math.min(1, source.audio.volume + steps * 0.05));
    }

    PwObjectTracker {
        objects: [root.source].filter(n => n)
    }
}
