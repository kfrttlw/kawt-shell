import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import "../profile"

// kawt's settings, one window, the one place they live (super + comma, start -> Settings): its
// pages on the left (look, screen, media, device, windows, kawt), the page on the right. Esc or
// × closes it; what's changed is saved at once (~/.local/state/kawt/settings.json).
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("settings", forScreen)
    property int page: 0
    readonly property var pages: [
        { key: "pageLook", icon: "picture" },
        { key: "pageScreen", icon: "crt" },
        { key: "pageMedia", icon: "rec" },
        { key: "pageDevice", icon: "key" },
        { key: "pageWindows", icon: "win" },
        { key: "pageKawt", icon: "logo" }
    ]
    readonly property int rowHeight: Metrics.fontSize + 13

    screen: forScreen
    visible: open
    color: "transparent"

    WlrLayershell.namespace: "kawt-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    OpenWatch {
        open: root.open
        onOpened: keys.forceActiveFocus()
    }

    // a click outside closes it
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.close()
    }

    Item {
        id: keys

        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                Panels.close();
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown)
                root.page = (root.page + 1) % root.pages.length;
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp)
                root.page = (root.page + root.pages.length - 1) % root.pages.length;
            else
                return;
            event.accepted = true;
        }
    }

    KWindow {
        id: win

        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(root.width - 60, Math.round(1000 * Metrics.scale))
        height: Math.min(root.height - Metrics.barHeight - 60, Math.round(660 * Metrics.scale))
        title: `${Strings.t("settingsTitle")} — kawt`
        icon: "gear"
        onCloseClicked: Panels.close()

        MouseArea {
            anchors.fill: parent
            onClicked: keys.forceActiveFocus()
        }

        // the pages: a sunk list, the open one in the accent
        Rectangle {
            id: list

            width: Math.round(170 * Metrics.scale)
            height: parent.height
            color: Colors.well

            Bevel {
                style: "sunk"
            }

            Column {
                x: 3
                y: 3
                width: parent.width - 6

                Repeater {
                    model: root.pages

                    Item {
                        id: entry

                        required property var modelData
                        required property int index
                        readonly property bool picked: index === root.page

                        width: parent.width
                        height: root.rowHeight

                        Rectangle {
                            anchors.fill: parent
                            visible: entry.picked
                            color: Colors.accent
                        }

                        PixIcon {
                            x: 5
                            anchors.verticalCenter: parent.verticalCenter
                            name: entry.modelData.icon
                        }

                        Label {
                            x: 27
                            anchors.verticalCenter: parent.verticalCenter
                            text: Strings.t(entry.modelData.key)
                            color: entry.picked ? Colors.onAccent : Colors.fg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.page = entry.index;
                                keys.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        // the page, scrolled when it's long
        Flickable {
            id: pane

            anchors.left: list.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            height: parent.height
            contentHeight: content.implicitHeight + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            CfgTab {
                id: content

                width: pane.width - 10
                profile: root
                page: root.page
            }
        }

        // where you are in a long page
        Rectangle {
            visible: pane.contentHeight > pane.height
            anchors.right: parent.right
            width: 3
            y: pane.visibleArea.yPosition * pane.height
            height: pane.visibleArea.heightRatio * pane.height
            color: Colors.dim
        }
    }
}
