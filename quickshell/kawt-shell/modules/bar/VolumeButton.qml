import Quickshell.Services.Pipewire
import qs.components

BracketButton {
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!sink?.audio?.muted
    readonly property int pct: Math.round((sink?.audio?.volume ?? 0) * 100)

    tag: "vol"
    label: muted ? "mute" : `${pct}%`

    onScrolled: steps => {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + steps * 0.05));
        }
    }

    PwObjectTracker {
        objects: [sink].filter(n => n)
    }
}
