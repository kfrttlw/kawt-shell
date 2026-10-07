import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// One step of the coder agent:
//      ~ I'll look for the settings file first          (its thinking, dim)
//   ⚙ read    src/settings.qml                 42 lines
//   ⚙ edit    src/settings.qml                 +3 −1
//     @ line 12
//     - button = false
//     + button = true                     [apply] [skip]
//   -- stopped --                                       (info / error)
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

            Label {
                text: "⚙"
                color: root.step.status === "running" || root.waiting ? Colors.accent : Colors.dim
                font.pixelSize: root.size

                // turns while it runs
                RotationAnimation on rotation {
                    running: root.step.status === "running"
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1200
                }
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
                visible: !!root.step.diff && !root.waiting
                label: root.showDiff ? "hide" : "diff"
                bordered: false
                onClicked: root.showDiff = !root.showDiff
            }
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

                Repeater {
                    // long diffs are cut in the view; the whole change is applied
                    model: root.step.diff ? [...root.step.diff.minus.map(l => "- " + l), ...root.step.diff.plus.map(l => "+ " + l)].slice(0, 60) : []

                    Label {
                        required property string modelData

                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: modelData
                        color: modelData.startsWith("-") ? Colors.warn : Colors.accent
                        font.pixelSize: root.size - 1
                    }
                }

                Label {
                    visible: root.step.diff ? root.step.diff.minus.length + root.step.diff.plus.length > 60 : false
                    text: "... (longer, shown cut)"
                    color: Colors.dim
                    font.pixelSize: root.size - 3
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
