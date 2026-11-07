import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// One step of the coder agent:
//      ~ I'll look for the settings file first          (its thinking, dim)
//   ≡ read    src/settings.qml                 42 lines
//   ≡ edit    src/settings.qml                 +3 −1
//     @ line 12
//       size: 12                          (two lines around it, dim)
//     - button = false
//     + button = true                     [apply] [skip]
//   ≡ run     npm test                         run it?
//     $ npm test
//     in the sandbox: no network, only the project writable   [run] [skip]
//   ≡ run     npm test        exit 0 · 12 lines · 3.1s · 2 files changed
//     ~ src/app.py   +4 −1   [diff]           (what it changed, each with its diff)
//     + out/report.txt  new  [diff]
//   -- stopped --                                       (info / error)
// ≡ is kawt's red block (components/RedBlock.qml): filling while the step runs, blinking while
// it waits for you, dim when done, in warn when it failed.
Item {
    id: root

    required property var step
    readonly property int size: Math.max(8, Metrics.fontSize + Settings.aiZoom)
    readonly property bool waiting: step.status === "waiting" && Coder.pending?.stepId === step.id
    property bool showDiff: true

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 2

        // ---- thinking
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: root.size * 2
            visible: root.step.kind === "think"
            wrapMode: Text.Wrap
            text: `~ ${root.step.text}`
            color: Colors.dim
            font.italic: true
            font.pixelSize: root.size - 1
        }

        // ---- info / error
        Label {
            Layout.fillWidth: true
            visible: root.step.kind === "info" || root.step.kind === "error"
            wrapMode: Text.Wrap
            text: root.step.kind === "error" ? `!! ${root.step.text}` : `-- ${root.step.text} --`
            color: root.step.kind === "error" ? Colors.warn : Colors.dim
            font.pixelSize: root.size - 1
        }

        // ---- a tool
        RowLayout {
            Layout.fillWidth: true
            visible: root.step.kind === "tool"
            spacing: Metrics.spacing

            RedBlock {
                Layout.alignment: Qt.AlignVCenter
                count: 3
                barWidth: Math.round(root.size * 0.75)
                barHeight: Math.max(2, Math.round(root.size * 0.16))
                mode: root.waiting ? "wait" : ({ running: "run", error: "error", skipped: "idle" })[root.step.status] ?? "done"
            }

            Label {
                Layout.preferredWidth: root.size * 0.6 * 7
                text: root.step.name
                color: Colors.accent
                font.pixelSize: root.size
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                text: root.step.arg
                color: Colors.fg
                font.pixelSize: root.size
            }

            Label {
                text: ({ running: "...", applied: `${root.step.text} applied`, skipped: "skipped", waiting: root.step.text })[root.step.status] ?? root.step.text
                color: ({ error: Colors.warn, applied: Colors.accent, waiting: Colors.accent })[root.step.status] ?? Colors.dim
                font.pixelSize: root.size - 2
            }

            BracketButton {
                visible: (!!root.step.diff || !!root.step.out || (root.step.files ?? []).length > 0) && !root.waiting
                label: root.showDiff ? "hide" : root.step.diff ? "diff" : "out"
                bordered: false
                onClicked: root.showDiff = !root.showDiff
            }
        }

        // ---- a command: waiting for [run], then what it printed
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: root.size * 2
            visible: !!root.step.cmd && (root.waiting || (root.showDiff && (!!root.step.out || !!root.step.unwatched))) && root.step.status !== "skipped"
            implicitHeight: runCol.implicitHeight + 8
            color: Colors.hoverFill
            border.color: root.waiting ? Colors.accent : Colors.border
            border.width: Metrics.borderWidth

            ColumnLayout {
                id: runCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    visible: root.waiting
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    text: `$ ${root.step.cmd ?? ""}`
                    color: Colors.fg
                    font.pixelSize: root.size - 1
                }

                Label {
                    Layout.fillWidth: true
                    visible: root.waiting
                    wrapMode: Text.Wrap
                    text: Coder.sandbox.startsWith("podman") ? `in podman (${Coder.sandbox.slice(7)}): no network, only the project writable, ${Settings.aiRunSecs}s at most` : `in a sandbox: no network, only the project writable, ${Settings.aiRunSecs}s at most`
                    color: Colors.dim
                    font.pixelSize: root.size - 3
                }

                // the last lines of what it printed
                Label {
                    Layout.fillWidth: true
                    visible: !root.waiting && !!root.step.out
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    maximumLineCount: 40
                    text: root.step.out ?? ""
                    color: root.step.status === "error" ? Colors.warn : Colors.fg
                    font.pixelSize: root.size - 2
                }

                // why there's no list of the files it changed
                Label {
                    Layout.fillWidth: true
                    visible: !root.waiting && !!root.step.unwatched
                    wrapMode: Text.Wrap
                    text: `the files it changed aren't known: ${root.step.unwatched ?? ""}. [undo] can't take them back`
                    color: Colors.dim
                    font.pixelSize: root.size - 3
                }

                RowLayout {
                    Layout.topMargin: 4
                    visible: root.waiting

                    BracketButton {
                        label: "run"
                        textColor: Colors.accent
                        onClicked: Coder.apply()
                    }

                    BracketButton {
                        label: "skip"
                        onClicked: Coder.skip()
                    }
                }
            }
        }

        // ---- what a command changed: a file a line, each one's diff behind [diff]
        Repeater {
            // the first 30 (a build may make hundreds): [changes] has them all
            model: root.step.kind === "tool" && root.showDiff ? (root.step.files ?? []).slice(0, 30) : []

            ColumnLayout {
                id: file

                required property var modelData
                property bool open: false
                readonly property bool made: modelData.how === "A"
                readonly property bool gone: modelData.how === "D"

                Layout.fillWidth: true
                Layout.leftMargin: root.size * 2
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacing

                    Label {
                        text: file.made ? "+" : file.gone ? "-" : "~"
                        color: file.made ? Colors.accent : file.gone ? Colors.warn : Colors.fg
                        font.pixelSize: root.size - 1
                    }

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        text: file.modelData.path
                        color: Colors.fg
                        font.pixelSize: root.size - 1
                    }

                    // +3 −1, new, gone, now runnable (chmod +x), now a link...
                    Label {
                        readonly property var m: file.modelData.modes
                        text: file.made ? (m[1] === "120000" ? "new link" : "new") : file.gone ? "gone" : m[0] !== m[1] ? ({ "100755": "now runnable", "120000": "now a link" })[m[1]] ?? (m[0] === "120000" ? "no link now" : "not runnable now") : file.modelData.plus === "-" ? "binary" : `+${file.modelData.plus} −${file.modelData.minus}`
                        color: Colors.dim
                        font.pixelSize: root.size - 2
                    }

                    BracketButton {
                        visible: file.modelData.diff.length > 0
                        label: file.open ? "hide" : "diff"
                        bordered: false
                        onClicked: file.open = !file.open
                    }
                }

                DiffLines {
                    Layout.fillWidth: true
                    Layout.leftMargin: root.size
                    visible: file.open
                    lines: file.open ? file.modelData.diff : []
                    size: root.size
                }
            }
        }

        Label {
            Layout.leftMargin: root.size * 2
            visible: root.showDiff && (root.step.files ?? []).length > 30
            text: `... ${(root.step.files ?? []).length - 30} more: [changes] has them all`
            color: Colors.dim
            font.pixelSize: root.size - 3
        }

        // ---- the diff of an edit
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: root.size * 2
            visible: !!root.step.diff && (root.showDiff || root.waiting) && root.step.status !== "skipped"
            implicitHeight: diffCol.implicitHeight + 8
            color: Colors.hoverFill
            border.color: root.waiting ? Colors.accent : Colors.border
            border.width: Metrics.borderWidth

            ColumnLayout {
                id: diffCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 0

                Label {
                    text: root.step.diff?.at ? `@ line ${root.step.diff.at}` : "@ new file"
                    color: Colors.dim
                    font.pixelSize: root.size - 3
                }

                // the change with two lines around it (steps from before had none)
                DiffLines {
                    Layout.fillWidth: true
                    readonly property var d: root.step.diff
                    lines: d ? [...(d.above ?? []).map(l => " " + l), ...d.minus.map(l => "-" + l), ...d.plus.map(l => "+" + l), ...(d.below ?? []).map(l => " " + l)] : []
                    max: 64
                    size: root.size
                }

                RowLayout {
                    Layout.topMargin: 4
                    visible: root.waiting

                    BracketButton {
                        label: "apply"
                        textColor: Colors.accent
                        onClicked: Coder.apply()
                    }

                    BracketButton {
                        label: "skip"
                        onClicked: Coder.skip()
                    }
                }
            }
        }
    }
}
