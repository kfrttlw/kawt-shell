import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// ┌ ▣ Screenshot · area ──────── × ┐
// │ ░░░░░░░░ the picture ░░░░░░░░░ │
// │ [Copy] [Save] [Open] [Ask]     │
// └────────────────────────────────┘
// bottom-right corner of the focused screen, after a screenshot (Settings.screenshotAsk). The
// shot is on the clipboard already. Click the picture: open it. Right click or ×: thrown away.
// Left alone it goes by itself after Screenshot.timeout (not while the pointer is on it), and
// then it's saved: a shot is never lost just because nobody answered (services/Screenshot.qml).
PanelWindow {
    id: root

    required property ShellScreen forScreen

    screen: forScreen
    visible: true // made only while a shot waits (Bar.qml)
    color: "transparent"
    implicitWidth: Metrics.toastWidth + 5
    implicitHeight: box.height + 5

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
        onTriggered: Screenshot.save()
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

    KWindow {
        id: box

        width: parent.width - 5
        height: chrome + body.implicitHeight
        title: [Strings.t("shotTitle"), Strings.t(({ region: "shotArea", window: "shotWindow", screen: "shotScreen" })[Screenshot.mode] ?? "")].filter(s => s && s !== "").join(" · ")
        icon: "picture"
        pad: 8
        focused: hover.hovered
        onCloseClicked: Screenshot.dismiss()

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

            width: parent.width
            spacing: Metrics.spacing

            // the picture, sunk
            Rectangle {
                Layout.fillWidth: true
                // as tall as the picture's shape asks, but a tall one doesn't fill the screen
                Layout.preferredHeight: Math.min(200, Math.round((width - 6) * pic.implicitHeight / Math.max(1, pic.implicitWidth))) + 6
                color: Colors.well

                Bevel {
                    style: "sunk"
                }

                Image {
                    id: pic

                    anchors.fill: parent
                    anchors.margins: 3
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
            }

            // Copy Save Open Edit Text Ask: edit and text only with satty / tesseract
            Flow {
                Layout.fillWidth: true
                spacing: 4

                PushButton {
                    small: true
                    text: Screenshot.copied ? Strings.t("copiedWord") : Strings.t("copyWord")
                    active: Screenshot.copied
                    onClicked: Screenshot.copy()
                }

                PushButton {
                    small: true
                    isDefault: true
                    text: Strings.t("shotSave")
                    onClicked: Screenshot.save()
                }

                PushButton {
                    small: true
                    text: Strings.t("shotOpen")
                    onClicked: Screenshot.open()
                }

                // arrows, boxes, text, blur: saved into this shot, then copy / save as usual
                PushButton {
                    visible: Screenshot.editor !== ""
                    small: true
                    text: Screenshot.editing ? Strings.t("shotEditing") : Strings.t("shotEdit")
                    enabled: !Screenshot.editing
                    onClicked: Screenshot.edit()
                }

                // the text in the picture, onto the clipboard
                PushButton {
                    visible: Screenshot.ocrLangs !== ""
                    small: true
                    text: Strings.t("shotText")
                    onClicked: Screenshot.readText()
                }

                // into the ai panel, to ask about it (a model that sees: ai -> settings -> pictures)
                PushButton {
                    small: true
                    text: Strings.t("shotAskAi")
                    onClicked: Ai.askAbout(Screenshot.shot)
                }
            }

            Label {
                Layout.fillWidth: true
                visible: text !== ""
                elide: Text.ElideRight
                text: Screenshot.textStatus
                color: Screenshot.textOk ? Colors.accent : Colors.dim
            }
        }
    }
}
