import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// The coder at work, on top of the wide panel: kawt's red block (the logo's), big, and next to
// it what's going on:
//   ▬▬▬▬▬   thinking · step 4/15
//   ▬▬▬▬▬   ▪▪▪▪▫▪▪       a mark a step of this task: dim it looked, light it changed
//   ▬▬▬▬▬   7 steps · 2 files changed      something, red now or waiting for you, warn
//   ▬▬▬▬▬                                  failed, the line color skipped
// The block (components/RedBlock.qml): one bar going down and up while the model thinks,
// filling bar by bar while a tool runs, blinking while something waits for you, still when
// idle. Everything comes from the panel: the coder service isn't loaded in chat mode.
RowLayout {
    id: root

    property string mode: "idle" // RedBlock's: idle | scan | run | wait
    property string label: ""
    property var steps: []
    property int changedCount: 0
    // the tool steps of the last task
    readonly property var trail: {
        let i = steps.length - 1;
        while (i >= 0 && steps[i].kind !== "task")
            i--;
        return steps.slice(i + 1).filter(s => s.kind === "tool");
    }

    spacing: Metrics.spacing * 2

    RedBlock {
        Layout.alignment: Qt.AlignVCenter
        mode: root.mode
        count: 6
        barWidth: Math.round(Metrics.fontSize * 2.4)
        barHeight: Math.max(2, Math.round(Metrics.fontSize * 0.3))
        spacing: Math.max(2, Math.round(Metrics.fontSize * 0.22))
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 3

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.mode === "idle" ? "idle" : root.label
            color: root.mode === "idle" ? Colors.dim : Colors.accent
            font.pixelSize: Metrics.fontSize - 1
        }

        // the last 40 steps, one mark each
        Row {
            visible: root.trail.length > 0
            spacing: 2

            Repeater {
                model: root.trail.slice(-40)

                Rectangle {
                    required property var modelData
                    readonly property string status: modelData.status

                    width: Math.max(3, Math.round(Metrics.fontSize * 0.4))
                    height: Math.round(Metrics.fontSize * 0.6)
                    color: status === "error" ? Colors.warn : status === "running" || status === "waiting" ? Colors.accent : status === "skipped" ? Colors.border : status === "applied" || (modelData.files ?? []).length > 0 ? Colors.fg : Colors.dim
                }
            }
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: `${root.trail.length} step${root.trail.length === 1 ? "" : "s"}${root.changedCount ? ` · ${root.changedCount} file${root.changedCount === 1 ? "" : "s"} changed` : ""}`
            visible: root.trail.length > 0
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
        }
    }
}
