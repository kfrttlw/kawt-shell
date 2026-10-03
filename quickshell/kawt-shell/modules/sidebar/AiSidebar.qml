import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Right-side panel with a terminal-style chat for a local model (ollama).
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isSidebarOpen(forScreen)
    property real progress: open ? 1 : 0

    screen: forScreen
    visible: open || progress > 0
    color: "transparent"
    implicitWidth: Metrics.sidebarWidth + Metrics.padding

    WlrLayershell.namespace: "kawt-sidebar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.right: true
    anchors.bottom: true

    Behavior on progress {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    onOpenChanged: if (open)
        input.input.forceActiveFocus()

    TitledBox {
        id: box

        x: Metrics.padding + (1 - root.progress) * width
        y: Metrics.barHeight + Metrics.spacing + titleOverhang
        width: Metrics.sidebarWidth - Metrics.padding
        height: parent.height - y - Metrics.padding
        title: `ai: ${Settings.ollamaModel}`
        hint: Ai.online ? "online" : "offline"

        Keys.onEscapePressed: Panels.sidebarOpen = false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + box.titleOverhang
            spacing: Metrics.spacing

            RowLayout {
                Layout.fillWidth: true

                Label {
                    Layout.fillWidth: true
                    text: Ai.online ? `ollama @ ${Settings.ollamaUrl.replace(/^https?:\/\//, "")}` : "ollama not reachable"
                    color: Ai.online ? Colors.dim : Colors.warn
                    font.pixelSize: Metrics.fontSize - 2
                }

                BracketButton {
                    visible: Ai.busy
                    label: "stop"
                    textColor: Colors.warn
                    bordered: false
                    onClicked: Ai.stop()
                }

                BracketButton {
                    label: "clear"
                    bordered: false
                    onClicked: Ai.send("/clear")
                }

                BracketButton {
                    label: "x"
                    bordered: false
                    onClicked: Panels.sidebarOpen = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Metrics.borderWidth
                color: Colors.border
            }

            ListView {
                id: log

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Metrics.padding
                model: Ai.messages
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: Qt.callLater(positionViewAtEnd)
                onContentHeightChanged: if (Ai.busy)
                    Qt.callLater(positionViewAtEnd)

                header: Label {
                    width: log.width
                    visible: log.count === 0
                    height: visible ? implicitHeight : 0
                    wrapMode: Text.Wrap
                    text: "local model chat.\n\n  enter         send\n  /model name   switch model\n  /models       list pulled models\n  /stop         stop the reply\n  /clear        wipe history\n  esc           close\n"
                    color: Colors.dim
                }

                delegate: ChatLine {
                    required property var modelData

                    width: log.width
                    kind: modelData.role
                    text: modelData.text
                }

                // the reply that is still streaming in
                footer: ChatLine {
                    width: log.width
                    visible: Ai.busy
                    height: visible ? implicitHeight : 0
                    topPadding: log.count > 0 ? log.spacing : 0
                    kind: "assistant"
                    text: Ai.partial
                    streaming: true
                }
            }

            TermInput {
                id: input

                Layout.fillWidth: true
                prompt: Ai.busy ? "~" : ">"
                placeholder: Ai.busy ? "thinking..." : "ask something..."
                onAccepted: t => {
                    // keep the draft while a reply is streaming; commands always go through
                    if (Ai.busy && !t.trim().startsWith("/"))
                        return;
                    Ai.send(t);
                    input.text = "";
                }
            }
        }
    }
}
