import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// The microphone, the old way: on / off switched on the right of the head; the input (when
// there's a choice), how loud it takes you; who listens now, a box each: unticked, that app
// hears silence and the others still hear you.
//
//   🎤 Microphone                          [x] On
//   ( ) built-in   (•) headset
//   ──────■──────── 67%
//   listening now
//   [x] discord
//   [ ] firefox
Popover {
    id: root

    readonly property PwNode source: Pipewire.defaultAudioSource
    // plain arrays, not list<PwNode>: a ScriptModel takes only those (qt won't assign a typed list
    // to its values, and the list stayed empty)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink && n.audio && n.properties["media.class"] === "Audio/Source")
    readonly property var apps: Pipewire.nodes.values.filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Audio")

    name: "mic"
    title: Strings.t("micTitle")
    icon: "mic"
    cardWidth: 320
    settingsPage: "media"
    switchText: root.source?.audio ? Strings.t("micOn") : ""
    switchOn: !(root.source?.audio?.muted ?? true)
    onSwitchToggled: if (root.source?.audio)
        root.source.audio.muted = !root.source.audio.muted

    PwObjectTracker {
        objects: [root.source, ...root.apps].filter(n => n)
    }

    Label {
        visible: !root.source
        text: Strings.t("noMic")
        color: Colors.dim
    }

    // the input, only when there is a choice
    Repeater {
        model: ScriptModel {
            values: root.sources.length > 1 ? root.sources : []
        }

        Check {
            required property PwNode modelData

            Layout.fillWidth: true
            radio: true
            text: modelData.description || modelData.name
            checked: modelData === root.source
            onToggled: Pipewire.preferredDefaultAudioSource = modelData
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.source !== null
        spacing: Metrics.spacing

        PixIcon {
            name: "mic"
        }

        LevelSlider {
            Layout.fillWidth: true
            value: root.source?.audio?.volume ?? 0
            onMoved: v => {
                if (root.source?.audio)
                    root.source.audio.volume = v;
            }
        }

        Label {
            Layout.preferredWidth: Math.round(Metrics.fontSize * 0.6 * 4)
            horizontalAlignment: Text.AlignRight
            text: `${Math.round((root.source?.audio?.volume ?? 0) * 100)}%`
        }
    }

    Label {
        visible: root.source !== null
        text: root.apps.length > 0 ? Strings.t("listeningNow") : Strings.t("nobodyListens")
        color: Colors.dim
    }

    // mutes only this app's recording stream: it hears silence, others still hear you
    Repeater {
        model: ScriptModel {
            values: root.apps
        }

        Check {
            id: app

            required property PwNode modelData

            Layout.fillWidth: true
            text: modelData.properties["application.name"] || modelData.description || modelData.name || "?"
            checked: !modelData.audio?.muted
            onToggled: if (modelData.audio)
                modelData.audio.muted = !modelData.audio.muted
        }
    }
}
