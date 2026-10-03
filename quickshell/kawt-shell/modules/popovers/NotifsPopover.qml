import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// dmesg-style notification log:
// [  4521.031] telegram: summary
//              body
Popover {
    id: root

    name: "notifs"
    title: "dmesg"
    cardWidth: 440

    onOpenChanged: if (open)
        Notifs.markRead()

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            Layout.fillWidth: true
            text: `${Notifs.count} message${Notifs.count === 1 ? "" : "s"}`
            color: Colors.dim
        }

        BracketButton {
            tag: "dnd"
            label: Settings.dnd ? "on" : "off"
            textColor: Settings.dnd ? Colors.accent : Colors.fg
            onClicked: Settings.dnd = !Settings.dnd
        }

        BracketButton {
            label: "clear"
            onClicked: Notifs.clear()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    Label {
        visible: Notifs.count === 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "-- no entries --"
        color: Colors.dim
    }

    Flickable {
        id: flick

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(400, log.implicitHeight)
        visible: Notifs.count > 0
        clip: true
        contentHeight: log.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: log

            width: flick.width
            spacing: 2

            Repeater {
                model: Notifs.list.slice(0, 50)

                Item {
                    id: entry

                    required property var modelData
                    readonly property bool critical: Notifs.isCritical(modelData)

                    width: log.width
                    implicitHeight: lines.implicitHeight + 2

                    Rectangle {
                        anchors.fill: parent
                        visible: entryArea.containsMouse
                        color: Colors.hoverFill
                    }

                    Column {
                        id: lines

                        width: parent.width

                        Row {
                            width: parent.width
                            spacing: Metrics.spacing

                            Label {
                                id: stampText

                                text: Notifs.stamp(entry.modelData)
                                color: Colors.dim
                            }

                            Label {
                                width: parent.width - stampText.width - parent.spacing
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: `${(entry.modelData.appName || "notify").toLowerCase()}: ${entry.modelData.summary}`
                                color: entry.critical ? Colors.warn : Colors.fg
                            }
                        }

                        Label {
                            x: stampText.width + Metrics.spacing
                            width: parent.width - x
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: entry.modelData.body
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 1
                        }
                    }

                    MouseArea {
                        id: entryArea

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                entry.modelData.dismiss();
                            } else {
                                Panels.close();
                                Notifs.activate(entry.modelData);
                            }
                        }
                    }
                }
            }
        }
    }

    Label {
        Layout.alignment: Qt.AlignRight
        visible: Notifs.count > 0
        text: "click: open · right click: dismiss"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 3
    }
}
