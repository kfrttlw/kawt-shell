import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// [mic on] · [mic ●] some app is recording (accent) · [mic off] muted
// click: the mic panel (apps, per-app mute), scroll: mic volume
BracketButton {
    id: root

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: !!source?.audio?.muted
    // apps recording right now: pipewire calls them "Stream/Input/Audio"
    readonly property int recording: Pipewire.nodes.values.filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Audio").length

    visible: source !== null
    tag: "mic"
    label: muted ? "off" : recording > 0 ? "●" : "on"
    textColor: muted ? Colors.dim : recording > 0 ? Colors.accent : Colors.fg

    onScrolled: steps => {
        if (source?.audio)
            source.audio.volume = Math.max(0, Math.min(1, source.audio.volume + steps * 0.05));
    }

    PwObjectTracker {
        objects: [root.source].filter(n => n)
    }
}
