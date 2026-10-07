import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.components
import qs.services

// Dropdown under [tray]. First level lists the apps:
//   ◉ telegram                 menu >
// left click activates, middle runs the secondary action, right click (or "menu >")
// opens the app's own menu right here, drawn as text:
//   [x] start minimized
//   ( ) option
//   settings                   >
// ".." goes back up.
Popover {
    id: root

    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)
    property var app: null // the app whose menu is shown, null = app list
    property var stack: [] // submenu entries we descended into
    readonly property var handle: stack.length > 0 ? stack[stack.length - 1] : app?.menu ?? null

    name: "tray"
    title: app ? (app.tooltipTitle || app.title || app.id || "tray").toLowerCase() : "tray"
    cardWidth: 300

    onPanelOpened: {
        app = null;
        stack = [];
    }

    function showMenu(item: var): void {
        stack = [];
        app = item;
    }

    QsMenuOpener {
        id: opener

        menu: root.handle
    }

    // ------------------------------------------------------------ app list
    Repeater {
        model: root.app ? [] : root.items

        Item {
            id: appRow

            required property var modelData

            Layout.fillWidth: true
            implicitHeight: appLine.implicitHeight + 6

            Rectangle {
                anchors.fill: parent
                visible: appArea.containsMouse
                color: Colors.hoverFill
            }

            RowLayout {
                id: appLine

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                spacing: Metrics.spacing

                TrayIcon {
                    Layout.preferredWidth: Metrics.fontSize + 2
                    Layout.preferredHeight: Metrics.fontSize + 2
                    item: appRow.modelData
                    colored: appArea.containsMouse
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: (appRow.modelData.tooltipTitle || appRow.modelData.title || appRow.modelData.id).toLowerCase()
                    color: appRow.modelData.status === Status.NeedsAttention ? Colors.accent : Colors.fg
                }

                Label {
                    visible: appRow.modelData.hasMenu
                    text: "menu >"
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }
            }

            MouseArea {
                id: appArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const item = appRow.modelData;
                    const onMenuLabel = mouse.x > width - 60;
                    if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                        Panels.close();
                    } else if (item.hasMenu && (mouse.button === Qt.RightButton || item.onlyMenu || onMenuLabel)) {
                        root.showMenu(item);
                    } else {
                        item.activate();
                        Panels.close();
                    }
                }
                onWheel: wheel => appRow.modelData.scroll(wheel.angleDelta.y / 120, false)
            }
        }
    }

    Label {
        visible: !root.app
        Layout.alignment: Qt.AlignRight
        text: "lmb open · rmb menu · mmb alt"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 3
    }

    // ------------------------------------------------------------ app menu
    MenuRow {
        visible: root.app !== null
        text: ".."
        onActivated: {
            if (root.stack.length > 0)
                root.stack = root.stack.slice(0, -1);
            else
                root.app = null;
        }
    }

    Label {
        visible: root.app !== null && opener.children.values.length === 0
        text: "-- empty --"
        color: Colors.dim
    }

    Repeater {
        model: root.app ? opener.children : []

        Item {
            id: row

            required property QsMenuEntry modelData

            Layout.fillWidth: true
            implicitHeight: modelData.isSeparator ? Metrics.spacing : line.implicitHeight

            Rectangle {
                visible: row.modelData.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Metrics.borderWidth
                color: Colors.border
            }

            MenuRow {
                id: line

                visible: !row.modelData.isSeparator
                width: parent.width
                enabled: row.modelData.enabled
                text: {
                    const e = row.modelData;
                    const checked = e.checkState === Qt.Checked;
                    const box = e.buttonType === QsMenuButtonType.CheckBox ? (checked ? "[x] " : "[ ] ")
                        : e.buttonType === QsMenuButtonType.RadioButton ? (checked ? "(*) " : "( ) ") : "";
                    return box + e.text.replace(/_(?!_)/g, ""); // drop GTK mnemonic underscores
                }
                suffix: row.modelData.hasChildren ? ">" : ""
                onActivated: {
                    if (row.modelData.hasChildren) {
                        root.stack = [...root.stack, row.modelData];
                    } else {
                        row.modelData.triggered();
                        Panels.close();
                    }
                }
            }
        }
    }

    component MenuRow: Item {
        id: menuRow

        property string text
        property string suffix

        signal activated

        Layout.fillWidth: true
        implicitHeight: label.implicitHeight + 2

        Rectangle {
            anchors.fill: parent
            visible: menuArea.containsMouse && menuRow.enabled
            color: Colors.hoverFill
        }

        Label {
            id: label

            anchors.left: parent.left
            anchors.right: suffixLabel.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: menuRow.text
            color: menuRow.enabled ? Colors.fg : Colors.dim
        }

        Label {
            id: suffixLabel

            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            text: menuRow.suffix
            color: Colors.dim
        }

        MouseArea {
            id: menuArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menuRow.activated() // disabled rows have `enabled: false`, which disables this too
        }
    }
}
