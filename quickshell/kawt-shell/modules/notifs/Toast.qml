import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// ┌─telegram──────[  4521.031]┐
// │ summary                   │
// │ body                      │
// └───────────────────────────┘
// left click: default action, right click: dismiss. Critical ones stay until handled.
Item {
    id: root

    required property var modelData
    readonly property bool critical: Notifs.isCritical(modelData)
    readonly property var buttons: modelData?.actions.filter(a => a.identifier !== "default" && a.text) ?? []

    implicitHeight: box.height + box.titleOverhang

    Timer {
        running: !root.critical && !hover.hovered
        interval: Notifs.popupTimeout
        onTriggered: Notifs.hide(root.modelData)
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
        width: parent.width
        height: body.implicitHeight + Metrics.padding * 2 + titleOverhang
        title: (root.modelData?.appName || "notify").toLowerCase()
        hint: Notifs.stamp(root.modelData)
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

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + box.titleOverhang
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
                Layout.topMargin: 2
                visible: root.buttons.length > 0
                spacing: Metrics.spacing

                Repeater {
                    model: root.buttons

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
