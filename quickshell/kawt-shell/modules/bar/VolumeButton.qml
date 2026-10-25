import Quickshell.Services.Pipewire
import qs.components
import qs.services

BracketButton {
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!sink?.audio?.muted
    readonly property int pct: Math.round((sink?.audio?.volume ?? 0) * 100)

    tag: "vol"
    label: muted ? "mute" : `${pct}%`

    // the same steps as the volume keys (a volume above 100% stays, see services/Audio.qml)
    onScrolled: steps => Audio.step(steps * 0.05)

    PwObjectTracker {
        objects: [sink].filter(n => n)
    }
}
