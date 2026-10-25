import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// ┌─screenshot─────────────[area]┐
// │ ░░░░░░░░ the picture ░░░░░░░ │
// │ [copy] [save] [open]     [x] │
// └──────────────────────────────┘
// bottom-right corner of the focused screen, after a screenshot (Settings.screenshotAsk).
// Click the picture: open it. Right click: away. It goes by itself after Screenshot.timeout,
// unless the pointer is on it; a shot that wasn't saved isn't kept (services/Screenshot.qml).
PanelWindow {
    id: root

    required property ShellScreen forScreen

    screen: forScreen
    visible: true // made only while a shot waits (Bar.qml)
    color: "transparent"
    implicitWidth: Metrics.toastWidth
    implicitHeight: box.height + box.titleOverhang

    WlrLayershell.namespace: "kawt-shot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.bottom: true
    anchors.right: true
    margins.bottom: Metrics.bottomGap + Metrics.padding * 2
    // step aside for the ai panel when it's open on this side, like the toasts
    margins.right: Metrics.padding + (Panels.isSidebarOpen(forScreen) && Settings.aiSide !== "left" ? (Settings.aiWide ? Math.round(forScreen.width * 0.62) : Metrics.sidebarWidth) : 0)

    // (it waits while the shot is being edited or read)
    Timer {
        running: !hover.hovered && !Screenshot.editing && !Screenshot.reading
        interval: Screenshot.timeout
        onTriggered: Screenshot.dismiss()
    }

    // edited: the same file, new picture
    Connections {
        target: Screenshot

        function onVersionChanged(): void {
            const s = pic.source;
            pic.source = "";
            pic.source = s;
        }
    }

    TitledBox {
        id: box

        y: titleOverhang
        width: parent.width
        height: body.implicitHeight + Metrics.padding * 2 + titleOverhang
        title: "screenshot"
        hint: ({ region: "area", window: "window", screen: "screen" })[Screenshot.mode] ?? ""
        border.color: hover.hovered ? Colors.dim : Colors.border

        // a handler also sees the pointer over the buttons, unlike MouseArea.containsMouse
        HoverHandler {
            id: hover
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: Screenshot.dismiss()
        }

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + box.titleOverhang
            spacing: Metrics.spacing

            Image {
                id: pic

                Layout.fillWidth: true
                // as tall as the picture's shape asks, but a tall one doesn't fill the screen
                Layout.preferredHeight: Math.min(200, Math.round(width * implicitHeight / Math.max(1, implicitWidth)))
                source: Screenshot.shot ? "file://" + Screenshot.shot : ""
                // decoded small (twice the box, still sharp on hidpi): a 4K shot isn't kept whole in memory
                sourceSize.width: Metrics.toastWidth * 2
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Screenshot.open()
                }
            }

            // [copy] [save] [open] [edit] [text] [ask] [x]: edit and text only with satty / tesseract
            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                BracketButton {
                    label: Screenshot.copied ? "copied" : "copy"
                    textColor: Screenshot.copied ? Colors.accent : Colors.fg
                    onClicked: Screenshot.copy()
                }

                BracketButton {
                    label: "save"
                    onClicked: Screenshot.save()
                }

                BracketButton {
                    label: "open"
                    onClicked: Screenshot.open()
                }

                // arrows, boxes, text, blur: saved into this shot, then copy / save as usual
                BracketButton {
                    visible: Screenshot.editor !== ""
                    label: Screenshot.editing ? "editing..." : "edit"
                    onClicked: Screenshot.edit()
                }

                // the text in the picture, onto the clipboard
                BracketButton {
                    visible: Screenshot.ocrLangs !== ""
                    label: "text"
                    onClicked: Screenshot.readText()
                }

                // into the ai panel, to ask about it (a model that sees: ai -> cfg -> pictures)
                BracketButton {
                    label: "ask"
                    onClicked: Ai.askAbout(Screenshot.shot)
                }

                BracketButton {
                    label: "x"
                    textColor: Colors.dim
                    onClicked: Screenshot.dismiss()
                }
            }

            Label {
                Layout.fillWidth: true
                visible: text !== ""
                elide: Text.ElideRight
                text: Screenshot.textStatus
                color: Screenshot.textStatus.startsWith("text copied") ? Colors.accent : Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }
        }
    }
}
