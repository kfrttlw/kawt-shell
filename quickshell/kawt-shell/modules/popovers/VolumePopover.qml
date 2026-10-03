import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components

Popover {
    id: root

    property bool expanded: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property list<PwNode> sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property list<PwNode> streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)

    name: "volume"
    title: "volume"
    cardWidth: 280

    PwObjectTracker {
        objects: [root.sink, ...root.streams].filter(n => n)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            text: root.sink?.audio?.muted ? "mute" : `${Math.round((root.sink?.audio?.volume ?? 0) * 100)}%`
        }

        Item {
            Layout.fillWidth: true
        }

        BracketButton {
            label: root.sink?.audio?.muted ? "unmute" : "mute"
            onClicked: if (root.sink?.audio)
                root.sink.audio.muted = !root.sink.audio.muted
        }

        BracketButton {
            label: root.streams.length > 0 ? (root.expanded ? "v" : ">") : "-"
            onClicked: if (root.streams.length > 0)
                root.expanded = !root.expanded
        }
    }

    LevelSlider {
        Layout.fillWidth: true
        value: root.sink?.audio?.volume ?? 0
        onMoved: v => {
            if (root.sink?.audio) {
                root.sink.audio.muted = false;
                root.sink.audio.volume = v;
            }
        }
    }

    // output devices, only when there's something to choose from
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.sinks.length > 1
        spacing: 2

        Label {
            Layout.topMargin: Metrics.spacing
            text: "-- output --"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        Repeater {
            model: root.sinks

            Label {
                required property PwNode modelData
                readonly property bool current: modelData === root.sink

                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `${current ? ">" : " "} ${modelData.description || modelData.name}`
                color: current ? Colors.accent : sinkArea.containsMouse ? Colors.fg : Colors.dim

                MouseArea {
                    id: sinkArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pipewire.preferredDefaultAudioSink = parent.modelData
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.expanded
        spacing: Metrics.spacing

        Label {
            Layout.topMargin: Metrics.spacing
            text: "-- apps --"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        Repeater {
            model: root.streams

            ColumnLayout {
                required property PwNode modelData

                Layout.fillWidth: true
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: modelData.properties["application.name"] || modelData.description || modelData.name || "?"
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }

                LevelSlider {
                    Layout.fillWidth: true
                    value: modelData.audio?.volume ?? 0
                    onMoved: v => {
                        if (modelData.audio) {
                            modelData.audio.muted = false;
                            modelData.audio.volume = v;
                        }
                    }
                }
            }
        }
    }
}
