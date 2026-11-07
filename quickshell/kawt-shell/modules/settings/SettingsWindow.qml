import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// kawt's settings, one window, the one place they live (super + comma, start -> Settings): its
// pages on the left (look, bar, screen, media, device, windows, kawt), the page on the right. A
// real window, as today and system are (components/AppWindow.qml): esc, × or Close closes it;
// what's changed is saved at once (~/.local/state/kawt/settings.json).
AppWindow {
    id: root

    // the screen it opened on, for what its pages open in turn (the style window, stripes...)
    property ShellScreen forScreen: null
    property int page: 0
    // the pages, in the list's order (each its own file here)
    readonly property var pages: [
        { key: "pageLook", icon: "picture", page: "look" },
        { key: "pageBar", icon: "logoWide", page: "bar" },
        { key: "pageScreen", icon: "lock", page: "screen" },
        { key: "pageMedia", icon: "vol2", page: "media" },
        { key: "pageDevice", icon: "key", page: "device" },
        { key: "pageWindows", icon: "desks", page: "windows" },
        { key: "pageKawt", icon: "info", page: "kawt" }
    ]
    readonly property int rowHeight: Metrics.fontSize + 13

    name: "settings"
    icon: "gear"
    title: `${Strings.t("settingsTitle")} — kawt`
    bodyWidth: Math.round(940 * Metrics.scale)
    bodyHeight: Math.min(Math.round(620 * Metrics.scale), (forScreen?.height ?? 768) - Metrics.barHeight - 120)

    // the page asked for (Panels.settingsPage: "bar", "screen"...), now or while it's open
    function openAt(name: string): void {
        const i = pages.findIndex(p => p.page === name);
        if (i >= 0)
            page = i;
        Panels.settingsPage = "";
    }

    Component.onCompleted: {
        forScreen = Quickshell.screens.find(s => s.name === Panels.focusedScreen) ?? Quickshell.screens[0] ?? null;
        openAt(Panels.settingsPage);
        keys.forceActiveFocus();
    }

    Connections {
        target: Panels

        function onSettingsPageChanged(): void {
            if (Panels.settingsPage !== "")
                root.openAt(Panels.settingsPage);
        }
    }

    // ↑ ↓ (and page up / down): the next page; esc goes on to the window, which closes
    Item {
        id: keys

        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown)
                root.page = (root.page + 1) % root.pages.length;
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp)
                root.page = (root.page + root.pages.length - 1) % root.pages.length;
            else
                return;
            event.accepted = true;
        }
    }

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
            sourceComponent: ({ look: lookPage, bar: barPage, screen: screenPage, media: mediaPage, device: devicePage, windows: windowsPage, kawt: kawtPage })[entry.page]
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
        id: screenPage

        ScreenPage {
            forScreen: root.forScreen
        }
    }

    Component {
        id: mediaPage

        MediaPage {
            forScreen: root.forScreen
        }
    }

    Component {
        id: devicePage

        DevicePage {
            forScreen: root.forScreen
        }
    }

    Component {
        id: windowsPage

        WindowsPage {
            forScreen: root.forScreen
        }
    }

    Component {
        id: kawtPage

        KawtPage {
            forScreen: root.forScreen
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
            onClicked: root.close()
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
