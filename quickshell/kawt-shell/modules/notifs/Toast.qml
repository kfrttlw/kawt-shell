import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// ┌─telegram──────[  4521.031]┐
// │ summary                   │
// │ body                      │
// └───────────────────────────┘
// left click: default action, right click: dismiss. Critical ones (and -t 0) stay until handled;
// the rest stay as long as the app asked (notify-send -t), or 6 s.
// With raised frames it's an old system's message box: a grey title bar (a critical one's in the
// light), an "i" or a "!" beside the words, its buttons raised at the bottom right.
Item {
    id: root

    required property var modelData
    readonly property bool critical: Notifs.isCritical(modelData)
    readonly property int timeout: Notifs.timeoutOf(modelData)
    readonly property var buttons: modelData?.actions.filter(a => a.identifier !== "default" && a.text) ?? []

    implicitHeight: box.height + box.titleOverhang + box.shadowRoom

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

    TitledBox {
        id: box

        y: titleOverhang
        width: parent.width - shadowRoom
        height: Math.max(body.implicitHeight, Colors.bevel ? sign.height : 0) + Metrics.padding * 2 + contentTop
        title: (root.modelData?.appName || "notify").toLowerCase()
        hint: Notifs.stamp(root.modelData)
        window: true
        focused: root.critical
        border.color: root.critical ? Colors.warn : hover.hovered ? Colors.dim : Colors.border

        // a handler also sees the pointer over the action buttons, unlike MouseArea.containsMouse
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

        // the message box's sign: "i", or "!" in the warning color for a critical one
        Rectangle {
            id: sign

            visible: Colors.bevel
            x: Metrics.padding
            y: box.contentTop + Metrics.padding
            width: Math.round(Metrics.fontSize * 2.2)
            height: width
            radius: width / 2
            color: root.critical ? Colors.warn : Colors.bg
            border.width: 1
            border.color: root.critical ? Colors.warn : Colors.dim

            Label {
                anchors.centerIn: parent
                text: root.critical ? "!" : "i"
                color: root.critical ? Colors.onAccent : Colors.fg
                font.bold: !Metrics.pixel
                font.pixelSize: Metrics.times(1.3)
            }
        }

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.leftMargin: Metrics.padding + (Colors.bevel ? sign.width + Metrics.padding : 0)
            anchors.topMargin: Metrics.padding + box.contentTop
            spacing: 2

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.modelData?.summary ?? ""
                color: root.critical ? Colors.warn : Colors.fg
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

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Colors.bevel ? Metrics.spacing : 2
                visible: root.buttons.length > 0
                spacing: Metrics.spacing
                layoutDirection: Colors.bevel ? Qt.RightToLeft : Qt.LeftToRight

                // right to left with raised frames, so the first one stays first
                Repeater {
                    model: Colors.bevel ? root.buttons.slice().reverse() : root.buttons

                    BracketButton {
                        required property var modelData

                        label: modelData.text.toLowerCase()
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
}
