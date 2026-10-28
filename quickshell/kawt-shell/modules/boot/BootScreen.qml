import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// kawt bios 0.1 · ThinkPad T14s Gen 1     (the model as the machine says it; a pc: its own)
//
// cpu    i5-8350U (8) ...................... ok
// mem    15872 MB .......................... ok
// disk   212G / 476G ....................... ok
// bat    39% ............................... ok
//
// starting kawt-shell ...................... ok
//
// [any key] skips
//
// A line every tenth of a second, a moment to read them, then the desktop comes on like an old
// tube: the picture opens from a bright line across the middle. Any key or click skips to that.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    property var facts: ({})
    property bool skipped: false
    readonly property int margin: Math.round(Metrics.fontSize * 3.5)
    readonly property int columnWidth: Math.round(Metrics.fontSize * 0.6 * 46) // ~46 columns: where the oks line up
    property int lit: 0 // lines shown so far
    property bool opening: false

    signal skip
    signal done

    readonly property var checks: [
        ["cpu", SysInfo.cpuModel + (SysInfo.cores > 0 ? ` (${SysInfo.cores})` : "")],
        ["mem", facts.mem ?? ""],
        ["disk", facts.disk ?? ""],
        ["bat", facts.bat ?? ""]
    ].filter(c => c[1])

    screen: forScreen
    color: "transparent"

    WlrLayershell.namespace: "kawt-boot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: opening ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    onSkippedChanged: if (skipped)
        open()

    function open(): void {
        if (opening)
            return;
        opening = true;
        lineTimer.stop();
        hold.stop();
        if (!Settings.crt) {
            done();
            return;
        }
        reveal.restart();
    }

    Timer {
        id: lineTimer

        running: true
        interval: 110
        repeat: true
        onTriggered: {
            root.lit++;
            if (root.lit >= root.checks.length + 6) {
                stop();
                hold.start();
            }
        }
    }

    Timer {
        id: hold

        interval: 900
        onTriggered: root.open()
    }

    // ---- the two halves of the dark screen, pulled apart from the middle when it opens
    Rectangle {
        id: upper

        width: parent.width
        height: parent.height / 2
        color: Colors.bg
    }

    Rectangle {
        id: lower

        y: parent.height - height
        width: parent.width
        height: parent.height / 2
        color: Colors.bg
    }

    // the beam where they part
    Rectangle {
        id: beam

        y: (parent.height - height) / 2
        width: parent.width
        height: Math.max(2, (parent.height - upper.height - lower.height) * 0.08)
        color: Colors.fg
        opacity: 0
    }

    SequentialAnimation {
        id: reveal

        NumberAnimation {
            target: lines
            property: "opacity"
            to: 0
            duration: 120
        }

        NumberAnimation {
            target: beam
            property: "opacity"
            to: 1
            duration: 60
        }

        ParallelAnimation {
            NumberAnimation {
                target: upper
                property: "height"
                to: 0
                duration: 300
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: lower
                property: "height"
                to: 0
                duration: 300
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: beam
                property: "opacity"
                to: 0
                duration: 300
                easing.type: Easing.InQuad
            }
        }

        ScriptAction {
            script: root.done()
        }
    }

    // ---- the text
    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            root.skip();
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.skip()
        }

        ColumnLayout {
            id: lines

            x: root.margin
            y: root.margin
            width: root.columnWidth
            spacing: 2

            Label {
                visible: root.lit > 0
                text: `kawt bios 0.1 · ${SysInfo.model || SysInfo.host || "this machine"}`
                font.bold: true
            }

            Item {
                implicitHeight: Metrics.fontSize
            }

            Repeater {
                model: root.checks

                RowLayout {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    visible: root.lit > index + 1
                    spacing: Metrics.spacing

                    Label {
                        Layout.preferredWidth: Math.round(Metrics.fontSize * 0.6 * 6)
                        text: modelData[0]
                        color: Colors.dim
                    }

                    Label {
                        Layout.maximumWidth: root.columnWidth * 0.7
                        elide: Text.ElideRight
                        text: modelData[1]
                    }

                    Leader {
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "ok"
                    }
                }
            }

            Item {
                implicitHeight: Metrics.fontSize
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.lit > root.checks.length + 2
                spacing: Metrics.spacing

                Label {
                    text: "starting kawt-shell"
                }

                Leader {
                    Layout.fillWidth: true
                }

                Label {
                    text: root.lit > root.checks.length + 3 ? "ok" : ""
                }
            }

            Item {
                implicitHeight: Metrics.fontSize
            }

            Row {
                visible: root.lit > root.checks.length + 4
                spacing: Metrics.spacing

                Brackets {
                    text: "any key"
                }

                Label {
                    text: "skips"
                    color: Colors.dim
                }
            }
        }
    }

    Component.onCompleted: keys.forceActiveFocus()
}
