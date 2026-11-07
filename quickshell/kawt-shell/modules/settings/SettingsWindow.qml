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
    // the new pages (look, bar) and the ones still in the old rows (CfgTab's pages, by number)
    readonly property var pages: [
        { key: "pageLook", icon: "picture", page: "look" },
        { key: "pageBar", icon: "logoWide", page: "bar" },
        { key: "pageScreen", icon: "lock", cfg: 1 },
        { key: "pageMedia", icon: "vol2", cfg: 2 },
        { key: "pageDevice", icon: "key", cfg: 3 },
        { key: "pageWindows", icon: "desks", cfg: 4 },
        { key: "pageKawt", icon: "info", cfg: 5 }
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
        height: Math.min(root.height - Metrics.barHeight - 60, Math.round(700 * Metrics.scale))
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

            width: Math.round(200 * Metrics.scale)
            height: parent.height - foot.height - 8
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
            anchors.rightMargin: 6
            height: parent.height - foot.height - 8
            contentHeight: shown.implicitHeight + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: shown

                readonly property var entry: root.pages[root.page]

                width: pane.width - 6
                sourceComponent: entry.page === "look" ? lookPage : entry.page === "bar" ? barPage : oldPage
            }
        }

        Component {
            id: lookPage

            LookPage {
                forScreen: root.forScreen
            }
        }

        Component {
            id: barPage

            BarPage {
                forScreen: root.forScreen
            }
        }

        Component {
            id: oldPage

            ColumnLayout {
                spacing: 6

                PageHead {
                    title: Strings.t(root.pages[root.page].key)
                    note: Strings.t("legacy")
                }

                CfgTab {
                    Layout.fillWidth: true
                    profile: root
                    page: root.pages[root.page].cfg
                }
            }
        }

        // the key, and Close
        RowLayout {
            id: foot

            anchors.bottom: parent.bottom
            width: parent.width

            Label {
                Layout.fillWidth: true
                text: Strings.t("settingsKey")
                color: Colors.dim
            }

            PushButton {
                text: Strings.t("close")
                onClicked: Panels.close()
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
