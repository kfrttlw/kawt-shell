import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// Always there, so a click never makes it vanish:
//   [mic on]  nobody listens · [mic ● discord]  an app is recording you (red) · [mic off]  muted
// click: mute / unmute, scroll: mic volume
BracketButton {
    id: root

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: !!source?.audio?.muted
    // apps recording right now: pipewire calls them "Stream/Input/Audio"
    readonly property var recorders: Pipewire.nodes.values.filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Audio")
    readonly property string who: (recorders[0]?.properties["application.name"] ?? "").toLowerCase()

    visible: source !== null
    tag: "mic"
    label: muted ? "off"
        : recorders.length === 0 ? "on"
        : "●" + (who ? ` ${who.length > 10 ? who.slice(0, 9) + "~" : who}` : "") + (recorders.length > 1 ? ` +${recorders.length - 1}` : "")
    textColor: muted ? Colors.dim : recorders.length > 0 ? Colors.warn : Colors.fg

    onClicked: if (source?.audio)
        source.audio.muted = !source.audio.muted
    onScrolled: steps => {
        if (source?.audio)
            source.audio.volume = Math.max(0, Math.min(1, source.audio.volume + steps * 0.05));
    }

    PwObjectTracker {
        objects: [root.source].filter(n => n)
    }
}
