import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// The messages, the old way: do not disturb switched on the right of the head; a sunk list, the
// newest first, a row each (the app's icon, the app · what it says, the time, its words under
// it); how many are new, [Clear]. A click opens one, a right click lets it go.
Popover {
    id: root

    // how many were new when it opened (opening reads them)
    property int wasNew: 0

    name: "notifs"
    title: Strings.t("notifsTitle")
    icon: Notifs.unread > 0 ? "bellDot" : "bell"
    cardWidth: 420
    switchText: Strings.t("dnd")
    switchOn: Settings.dnd
    onSwitchToggled: Settings.dnd = !Settings.dnd
    settingsPage: "screen"

    onPanelOpened: {
        wasNew = Notifs.unread;
        Notifs.markRead();
    }

    Label {
        visible: Notifs.count === 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: `— ${Strings.t("noMessages")} —`
        color: Colors.dim
    }

    // the list, sunk in a field
    Rectangle {
        Layout.fillWidth: true
        visible: Notifs.count > 0
        implicitHeight: flick.height + 6
        color: Colors.well

        Bevel {
            style: "sunk"
        }

        Flickable {
            id: flick

            x: 3
            y: 3
            width: parent.width - 6
            height: Math.min(Math.round(360 * Metrics.scale), log.implicitHeight)
            clip: true
            contentHeight: log.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: log

                width: flick.width

                Repeater {
                    model: ScriptModel {
                        values: Notifs.list.slice(0, 50)
                    }

                    Item {
                        id: entry

                        required property var modelData
                        required property int index
                        readonly property bool critical: Notifs.isCritical(modelData)
                        readonly property string picture: modelData?.image || modelData?.appIcon || (DesktopEntries.heuristicLookup(modelData?.appName ?? "")?.icon ?? "")

                        width: log.width
                        implicitHeight: lines.implicitHeight + 10

                        Rectangle {
                            anchors.fill: parent
                            visible: entryArea.containsMouse
                            color: Colors.hoverFill
                        }

                        // a groove between two
                        Rule {
                            visible: entry.index > 0
                            width: parent.width
                        }

                        AppIcon {
                            id: pic

                            x: 4
                            y: 6
                            width: 16
                            height: 16
                            visible: entry.picture !== ""
                            icon: entry.picture
                            name: entry.modelData.appName ?? ""
                            colored: true
                        }

                        PixIcon {
                            x: 4
                            y: 6
                            visible: entry.picture === ""
                            name: entry.critical ? "warn" : "chat"
                        }

                        Column {
                            id: lines

                            x: 26
                            y: 5
                            width: parent.width - x - 4
                            spacing: 2

                            Item {
                                width: parent.width
                                height: head.implicitHeight

                                Label {
                                    id: head

                                    width: parent.width - when.implicitWidth - 8
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: [entry.modelData.appName, entry.modelData.summary].filter(s => s).join(" · ")
                                    color: entry.critical ? Colors.warn : Colors.fg
                                }

                                Label {
                                    id: when

                                    anchors.right: parent.right
                                    text: Notifs.timeOf(entry.modelData)
                                    color: Colors.dim
                                }
                            }

                            Label {
                                width: parent.width
                                visible: text !== ""
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: entry.modelData.body
                                color: Colors.dim
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
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Notifs.count > 0
        spacing: Metrics.spacing

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.wasNew > 0 ? Strings.t("nNew").arg(root.wasNew) : Strings.t("notifsHow")
            color: Colors.dim
        }

        PushButton {
            minWidth: 0
            text: Strings.t("clearAll")
            onClicked: Notifs.clear()
        }
    }
}
