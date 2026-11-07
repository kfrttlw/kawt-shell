import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services
import "../../utils/pixicons.js" as Pix

// the speaker: off, quiet, loud. The wheel steps the volume like the volume keys (a volume above
// 100% stays, see services/Audio.qml); a click opens the mixer
BarIcon {
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!sink?.audio?.muted
    readonly property int pct: Math.round((sink?.audio?.volume ?? 0) * 100)

    icon: Pix.volume(pct / 100, muted)
    tip: muted ? Strings.t("muted") : Strings.t("volume").arg(pct)
    onScrolled: steps => Audio.step(steps * 0.05)

    PwObjectTracker {
        objects: [sink].filter(n => n)
    }
}
