import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// The sound, the old way: the master standing on the left with its % under it, the apps that
// play beside it, a slider each; mute; the output (when there's more than one). The wheel on
// the bar's icon: ±5%.
//
//   all  apps                                  output
//   ┃    firefox   ──────■──        (•) speakers ( ) headphones
//   ■    telegram  ───■─────
//   ┃
//   44%  [ ] mute
Popover {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    // plain arrays, not list<PwNode>: a ScriptModel takes only those (qt won't assign a typed list
    // to its values, and the list stayed empty)
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)

    name: "volume"
    title: Strings.t("soundTitle")
    icon: "vol2"
    cardWidth: 340
    settingsPage: "media"
    note: Strings.t("wheelNote")

    PwObjectTracker {
        objects: [root.sink, ...root.streams].filter(n => n)
    }

    // the output, when there's a choice
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.sinks.length > 1
        spacing: 2

        Repeater {
            model: ScriptModel {
                values: root.sinks
            }

            Check {
                required property PwNode modelData

                Layout.fillWidth: true
                radio: true
                text: modelData.description || modelData.name
                checked: modelData === root.sink
                onToggled: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.padding

        // all of it, standing
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 4

            Label {
                text: Strings.t("soundAll")
                color: Colors.dim
            }

            LevelSlider {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: Math.max(96, apps.implicitHeight)
                vertical: true
                value: root.sink?.audio?.volume ?? 0
                onMoved: v => {
                    if (root.sink?.audio) {
                        root.sink.audio.muted = false;
                        root.sink.audio.volume = v;
                    }
                }
            }

            Label {
                text: root.sink?.audio?.muted ? "—" : `${Math.round((root.sink?.audio?.volume ?? 0) * 100)}%`
                color: Colors.dim
            }
        }

        // the apps that play
        ColumnLayout {
            id: apps

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 4

            Label {
                text: Strings.t("soundApps")
                color: Colors.dim
            }

            Label {
                visible: root.streams.length === 0
                text: Strings.t("soundNoApps")
                color: Colors.dim
            }

            Repeater {
                model: ScriptModel {
                    values: root.streams
                }

                RowLayout {
                    id: app

                    required property PwNode modelData

                    Layout.fillWidth: true
                    spacing: Metrics.spacing

                    Label {
                        Layout.preferredWidth: Math.round(Metrics.fontSize * 0.6 * 11)
                        elide: Text.ElideRight
                        text: app.modelData.properties["application.name"] || app.modelData.description || app.modelData.name || "?"
                    }

                    LevelSlider {
                        Layout.fillWidth: true
                        value: app.modelData.audio?.volume ?? 0
                        onMoved: v => {
                            if (app.modelData.audio) {
                                app.modelData.audio.muted = false;
                                app.modelData.audio.volume = v;
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Check {
                text: Strings.t("soundMute")
                checked: root.sink?.audio?.muted ?? false
                onToggled: if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted
            }
        }
    }
}
