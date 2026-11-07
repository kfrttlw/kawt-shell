import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

// A small menu that drops from a bar item (a right click on a desk, the "+3" of the windows that
// didn't fit): raised, a hard shadow, a line each, the picked one in the accent.
//   items: [{ text, checked?, icon?, action }, "-" (a line), ...]
// open() shows it, a click on a line runs its action and closes it, a click elsewhere closes it.
Item {
    id: root

    property var items: []
    property Item target: parent
    property bool shown: false
    readonly property int lineHeight: Metrics.fontSize + 11

    function open(): void {
        shown = true;
    }

    function close(): void {
        shown = false;
    }

    PopupWindow {
        id: win

        visible: root.shown
        anchor.item: root.target
        anchor.rect.y: Metrics.barBottom ? -2 : (root.target?.height ?? 0) + 2
        anchor.rect.height: 0
        anchor.rect.width: 0
        anchor.edges: Metrics.barBottom ? Edges.Top | Edges.Left : Edges.Bottom | Edges.Left
        anchor.gravity: Metrics.barBottom ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Right
        implicitWidth: Math.max(Math.round(160 * Metrics.scale), list.implicitWidth + 4) + 4
        implicitHeight: list.implicitHeight + 8
        color: "transparent"

        // the hard shadow, 4 px down and right
        Rectangle {
            x: 4
            y: 4
            width: parent.width - 4
            height: parent.height - 4
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        Rectangle {
            width: parent.width - 4
            height: parent.height - 4
            color: Colors.face

            Bevel {
                style: "raised"
            }

            ColumnLayout {
                id: list

                x: 2
                y: 2
                width: parent.width - 4
                spacing: 0

                Repeater {
                    model: root.items

                    Item {
                        id: line

                        required property var modelData
                        readonly property bool rule: modelData === "-"

                        Layout.fillWidth: true
                        implicitWidth: words.implicitWidth + 40
                        implicitHeight: rule ? 6 : root.lineHeight

                        Rectangle {
                            visible: line.rule
                            x: 2
                            width: parent.width - 4
                            y: 2
                            height: 1
                            color: Colors.lo

                            Rectangle {
                                y: 1
                                width: parent.width
                                height: 1
                                color: Colors.hi
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !line.rule && area.containsMouse
                            color: Colors.accent
                        }

                        PixIcon {
                            visible: !line.rule && (line.modelData.checked ?? false)
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            ink: area.containsMouse ? Colors.onAccent : "transparent"
                        }

                        Label {
                            id: words

                            visible: !line.rule
                            x: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: line.rule ? "" : line.modelData.text
                            color: area.containsMouse ? Colors.onAccent : (line.modelData.warn ? Colors.accent : Colors.fg)
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            enabled: !line.rule
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.close();
                                line.modelData.action?.();
                            }
                        }
                    }
                }
            }
        }

        // a click anywhere else on the bar closes it (and Escape)
        Shortcut {
            sequence: "Escape"
            onActivated: root.close()
        }
    }
}
