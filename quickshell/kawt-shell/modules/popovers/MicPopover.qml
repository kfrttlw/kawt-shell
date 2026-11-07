import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// ┌─microphone─────────────────────┐
// │ [on] off              67%      │
// │ [######################-------]│
// │ -- listening now --            │
// │ > discord              [on]    │  per-app: cut one app off, keep the others
// │   firefox              [off]   │
// │ -- input --                    │
// │ > built-in mic                 │  (only if there is more than one)
// └────────────────────────────────┘
Popover {
    id: root

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink && n.audio && n.properties["media.class"] === "Audio/Source")
    readonly property list<PwNode> apps: Pipewire.nodes.values.filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Audio")

    name: "mic"
    title: "microphone"
    cardWidth: 300

    PwObjectTracker {
        objects: [root.source, ...root.apps].filter(n => n)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        BracketButton {
            label: "on"
            active: !(root.source?.audio?.muted ?? true)
            textColor: !(root.source?.audio?.muted ?? true) ? Colors.accent : Colors.dim
            onClicked: if (root.source?.audio)
                root.source.audio.muted = false
        }

        BracketButton {
            label: "off"
            active: root.source?.audio?.muted ?? false
            textColor: root.source?.audio?.muted ? Colors.accent : Colors.dim
            onClicked: if (root.source?.audio)
                root.source.audio.muted = true
        }

        Item {
            Layout.fillWidth: true
        }

        Label {
            text: `${Math.round((root.source?.audio?.volume ?? 0) * 100)}%`
            color: Colors.dim
        }
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
        Layout.topMargin: Metrics.spacing
        text: root.apps.length > 0 ? "-- listening now --" : "-- nobody is listening --"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    Repeater {
        model: ScriptModel {
            values: root.apps
        }

        RowLayout {
            id: app

            required property PwNode modelData
            readonly property bool appMuted: !!modelData.audio?.muted

            Layout.fillWidth: true
            spacing: Metrics.spacing

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: (app.appMuted ? "  " : "> ") + (app.modelData.properties["application.name"] || app.modelData.description || app.modelData.name || "?").toLowerCase()
                color: app.appMuted ? Colors.dim : Colors.fg
            }

            // mutes only this app's recording stream: it hears silence, others still hear you
            BracketButton {
                label: app.appMuted ? "off" : "on"
                textColor: app.appMuted ? Colors.dim : Colors.accent
                bordered: false
                onClicked: if (app.modelData.audio)
                    app.modelData.audio.muted = !app.modelData.audio.muted
            }
        }
    }

    // choose the input, only when there is a choice
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.sources.length > 1
        spacing: 2

        Label {
            Layout.topMargin: Metrics.spacing
            text: "-- input --"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        Repeater {
            model: ScriptModel {
                values: root.sources
            }

            Label {
                required property PwNode modelData
                readonly property bool current: modelData === root.source

                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `${current ? ">" : " "} ${(modelData.description || modelData.name).toLowerCase()}`
                color: current ? Colors.accent : srcArea.containsMouse ? Colors.fg : Colors.dim

                MouseArea {
                    id: srcArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pipewire.preferredDefaultAudioSource = parent.modelData
                }
            }
        }
    }
}
