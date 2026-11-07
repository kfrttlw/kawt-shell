import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// A message the old way: a small window titled with the app (an urgent one's title red), its
// icon big beside the words, the app's own buttons and OK at the bottom right.
//
//   ┌ ▣ telegram ─────────────────── × ┐
//   │ [icon]  anna                      │
//   │         see you at seven?         │
//   │                  [ Reply ] [ OK ] │
//   └───────────────────────────────────┘
// A click on the words: its default action; right click, OK or ×: away. Urgent ones (and -t 0)
// stay until handled; the rest stay as long as the app asked (notify-send -t), or 6 s, longer
// while the pointer is over it.
Item {
    id: root

    required property var modelData
    readonly property bool critical: Notifs.isCritical(modelData)
    readonly property int timeout: Notifs.timeoutOf(modelData)
    readonly property var buttons: modelData?.actions.filter(a => a.identifier !== "default" && a.text) ?? []
    // the picture the app sent, its icon, or the one of its desktop entry
    readonly property string picture: modelData?.image || modelData?.appIcon || (DesktopEntries.heuristicLookup(modelData?.appName ?? "")?.icon ?? "")

    implicitHeight: win.height + 5

    Timer {
        running: !root.critical && root.timeout > 0 && !hover.hovered
        interval: root.timeout
        onTriggered: Notifs.expired(root.modelData)
    }

    Connections {
        target: root.modelData

        function onClosed(): void {
            Notifs.hide(root.modelData);
        }
    }

    KWindow {
        id: win

        width: parent.width - 5
        height: chrome + Math.max(body.implicitHeight, 32)
        title: root.modelData?.appName || "notify"
        icon: root.critical ? "warn" : "chat"
        urgent: root.critical
        pad: 8
        onCloseClicked: root.modelData.dismiss()

        // a handler also sees the pointer over the buttons, unlike MouseArea.containsMouse
        HoverHandler {
            id: hover
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    root.modelData.dismiss();
                else
                    Notifs.activate(root.modelData);
            }
        }

        // the app's picture, or a pixel one
        AppIcon {
            id: pic

            visible: root.picture !== ""
            width: 32
            height: 32
            icon: root.picture
            name: root.modelData?.appName ?? ""
            colored: true
        }

        PixIcon {
            visible: root.picture === ""
            size: 32
            name: root.critical ? "warn" : "chat"
        }

        ColumnLayout {
            id: body

            x: 32 + 10
            width: parent.width - x
            spacing: 2

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.modelData?.summary ?? ""
            }

            Label {
                Layout.fillWidth: true
                visible: text !== ""
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.modelData?.body ?? ""
                color: Colors.dim
            }

            // the app's buttons, then OK
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                spacing: 4
                layoutDirection: Qt.RightToLeft

                PushButton {
                    minWidth: Math.round(60 * Metrics.scale)
                    text: Strings.t("ok")
                    onClicked: root.modelData.dismiss()
                }

                // right to left, so the first one stays first
                Repeater {
                    model: root.buttons.slice().reverse()

                    PushButton {
                        required property var modelData

                        minWidth: 0
                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
}
