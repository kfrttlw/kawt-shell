import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.utils

// ┌─power───────────────────────── esc┐
// │ user@host · up 3h 12m             │
// │ > shutdown -h now                 │
// │   reboot                          │
// │   suspend                         │
// │   logout                          │
// │   lock                            │
// │ shutting down in 4...  esc cancel │
// └───────────────────────────────────┘
// super + escape. arrows / j k pick, enter runs: lock and suspend at once, the rest after a
// 5 s countdown (enter again: now, esc: cancel).
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("power", forScreen)
    readonly property var actions: [
        { name: "shutdown -h now", word: "shutting down", delay: true },
        { name: "reboot", word: "rebooting", delay: true },
        { name: "suspend", word: "", delay: false },
        { name: "logout", word: "logging out", delay: true },
        { name: "lock", word: "", delay: false }
    ]
    property int current: 0
    property int countdown: 0 // seconds left, 0 = not counting

    screen: forScreen
    visible: open
    color: "transparent"

    WlrLayershell.namespace: "kawt-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    onOpenChanged: {
        countdown = 0;
        if (open) {
            current = 0;
            box.forceActiveFocus();
        }
    }

    function run(i: int): void {
        const a = actions[i];
        countdown = 0;
        Panels.close();
        if (i === 0)
            Quickshell.execDetached(["systemctl", "poweroff"]);
        else if (i === 1)
            Quickshell.execDetached(["systemctl", "reboot"]);
        else if (i === 2)
            Quickshell.execDetached(["systemctl", "suspend"]);
        else if (i === 3)
            Hypr.exit();
        else
            Panels.locked = true;
    }

    // enter on an action: the safe ones run at once, the rest start the countdown;
    // enter during the countdown runs it now
    function pick(i: int): void {
        if (countdown > 0 && i === current) {
            run(current);
            return;
        }
        current = i;
        if (actions[i].delay)
            countdown = 5;
        else
            run(i);
    }

    Timer {
        running: root.countdown > 0
        repeat: true
        interval: 1000
        onTriggered: {
            root.countdown--;
            if (root.countdown === 0)
                root.run(root.current);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.close()
        }
    }

    TitledBox {
        id: box

        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: 380
        height: body.implicitHeight + Metrics.padding * 2 + titleOverhang
        title: "power"
        hint: "esc"

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.countdown > 0)
                    root.countdown = 0;
                else
                    Panels.close();
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.countdown = 0;
                root.current = (root.current + root.actions.length - 1) % root.actions.length;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Tab) {
                root.countdown = 0;
                root.current = (root.current + 1) % root.actions.length;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.pick(root.current);
            } else {
                return;
            }
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: box.forceActiveFocus()
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
                Layout.bottomMargin: Metrics.spacing
                elide: Text.ElideRight
                text: `${SysInfo.user}@${SysInfo.host} · up ${Fmt.uptime(SysInfo.uptime)}`
                color: Colors.dim
            }

            Repeater {
                model: root.actions

                Item {
                    id: action

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.current

                    Layout.fillWidth: true
                    implicitHeight: actionLabel.implicitHeight + 6

                    Rectangle {
                        anchors.fill: parent
                        visible: action.selected
                        color: Colors.hoverFill
                    }

                    Label {
                        id: actionLabel

                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: (action.selected ? "> " : "  ") + action.modelData.name
                        color: action.selected ? (action.index < 2 ? Colors.warn : Colors.accent) : Colors.fg
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: if (root.countdown === 0)
                            root.current = action.index
                        onClicked: root.pick(action.index)
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                elide: Text.ElideRight
                text: root.countdown > 0 ? `${root.actions[root.current].word} in ${root.countdown}...   enter: now · esc: cancel` : "↑↓ pick · enter run · esc close"
                color: root.countdown > 0 ? Colors.warn : Colors.dim
                font.pixelSize: root.countdown > 0 ? Metrics.fontSize : Metrics.fontSize - 2
            }
        }
    }
}
