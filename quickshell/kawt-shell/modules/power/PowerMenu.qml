import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.utils

// super + escape, or start -> Shut down…: the old systems' dialog, the one place with the power
// buttons. "What do you want the computer to do?", a radio button each, OK / Cancel; the screen
// behind it goes dark in dots. Arrows or the underlined letter pick, enter is OK. Sleep and lock
// at once (sleep locks the screen first); shut down, restart and log out after a 5 s countdown
// in its own small window (Now: at once, Cancel or esc: not).
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("power", forScreen)
    readonly property var actions: [
        { word: Strings.t("powerOff"), key: Strings.ru ? 0 : 0, icon: "power", wait: "shuttingDown", delay: true },
        { word: Strings.t("reboot"), key: 0, icon: "restart", wait: "rebooting", delay: true },
        { word: Strings.t("suspend"), key: Strings.ru ? 0 : 2, icon: "moon", note: Strings.t("sleepNote"), delay: false },
        { word: Strings.t("logout"), key: Strings.ru ? 1 : 0, icon: "door", wait: "loggingOut", delay: true },
        { word: Strings.t("lock"), key: Strings.ru ? 0 : 3, icon: "lock", delay: false }
    ]
    property int current: 0
    property int countdown: 0 // seconds left, 0 = not counting

    // "<u>В</u>ыключить": the letter that picks it
    function underlined(a: var): string {
        const w = a.word, k = a.key;
        return `${w.slice(0, k)}<u>${w[k]}</u>${w.slice(k + 1)}`;
    }

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

    // closing cancels a countdown
    OpenWatch {
        open: root.open
        onOpened: {
            root.countdown = 0;
            root.current = 0;
            keys.forceActiveFocus();
        }
        onClosed: root.countdown = 0
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
            Panels.suspend(); // locks first: never wake up to an open desktop
        else if (i === 3)
            Hypr.exit();
        else
            Panels.lock(false);
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

    // the screen behind, dark in dots; a click there is Cancel
    Dots {
        anchors.fill: parent
        base: "transparent"
        dots: Qt.rgba(0, 0, 0, 0.85)

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.close()
        }
    }

    Item {
        id: keys

        focus: true
        Keys.onPressed: event => {
            const n = root.actions.length;
            if (event.key === Qt.Key_Escape) {
                if (root.countdown > 0)
                    root.countdown = 0;
                else
                    Panels.close();
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.countdown = 0;
                root.current = (root.current + n - 1) % n;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Tab) {
                root.countdown = 0;
                root.current = (root.current + 1) % n;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.pick(root.current);
            } else {
                // the underlined letter
                const i = root.actions.findIndex(a => event.text && a.word[a.key].toLowerCase() === event.text.toLowerCase());
                if (i < 0 || root.countdown > 0)
                    return;
                root.countdown = 0;
                root.current = i;
            }
            event.accepted = true;
        }
    }

    // what to do
    KWindow {
        id: ask

        visible: root.countdown === 0
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.round(400 * Metrics.scale)
        height: chrome + askBody.implicitHeight
        title: Strings.t("powerTitle")
        icon: "power"
        onCloseClicked: Panels.close()

        MouseArea {
            anchors.fill: parent
            onClicked: keys.forceActiveFocus()
        }

        ColumnLayout {
            id: askBody

            width: parent.width
            spacing: 2

            RowLayout {
                spacing: 12

                PixIcon {
                    Layout.alignment: Qt.AlignTop
                    name: "power"
                    size: 32
                }

                ColumnLayout {
                    spacing: 2

                    Label {
                        Layout.bottomMargin: 6
                        text: Strings.t("powerAsk")
                    }

                    Repeater {
                        model: root.actions

                        Item {
                            id: choice

                            required property var modelData
                            required property int index
                            readonly property bool picked: index === root.current

                            implicitWidth: radioRow.implicitWidth
                            implicitHeight: radioRow.implicitHeight + (note.visible ? note.implicitHeight : 0) + 2

                            Row {
                                id: radioRow

                                spacing: 4

                                PixIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: choice.picked ? "radioOn" : "radioOff"
                                }

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    textFormat: Text.StyledText // our own words only
                                    text: root.underlined(choice.modelData)
                                }
                            }

                            Label {
                                id: note

                                visible: (choice.modelData.note ?? "") !== ""
                                x: 20
                                y: radioRow.height
                                text: choice.modelData.note ?? ""
                                color: Colors.dim
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.current = choice.index;
                                    keys.forceActiveFocus();
                                }
                                onDoubleClicked: root.pick(choice.index)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 8
                spacing: 6

                DialogButton {
                    text: Strings.t("ok")
                    isDefault: true
                    onClicked: root.pick(root.current)
                }

                DialogButton {
                    text: Strings.t("cancel")
                    onClicked: Panels.close()
                }
            }
        }
    }

    // the countdown: shutting down in 4 s…
    KWindow {
        visible: root.countdown > 0
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.round(400 * Metrics.scale)
        height: chrome + waitBody.implicitHeight
        title: root.actions[root.current].word
        icon: root.actions[root.current].icon
        onCloseClicked: root.countdown = 0

        ColumnLayout {
            id: waitBody

            width: parent.width
            spacing: 4

            RowLayout {
                spacing: 12

                PixIcon {
                    Layout.alignment: Qt.AlignTop
                    name: root.actions[root.current].icon
                    size: 32
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: Strings.t(root.actions[root.current].wait ?? "shuttingDown").arg(root.countdown)
                    }

                    Label {
                        text: Strings.t("saveFiles")
                        color: Colors.dim
                    }

                    // the seconds gone, in red segments
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: 18
                        color: Colors.well

                        Bevel {
                            style: "sunk"
                        }

                        Row {
                            x: 3
                            y: 3
                            spacing: 2

                            Repeater {
                                model: Math.round((5 - root.countdown + 1) / 5 * 12)

                                Rectangle {
                                    width: 8
                                    height: 12
                                    color: Colors.accent
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 8
                spacing: 6

                DialogButton {
                    text: Strings.t("now")
                    isDefault: true
                    onClicked: root.run(root.current)
                }

                DialogButton {
                    text: Strings.t("cancel")
                    onClicked: root.countdown = 0
                }
            }
        }
    }

    // OK, Cancel: raised, the default one with a dark frame round it
    component DialogButton: BarBox {
        id: button

        property string text: ""
        property bool isDefault: false

        plain: false
        implicitWidth: Math.max(Math.round(84 * Metrics.scale), words.implicitWidth + 20)
        implicitHeight: Metrics.fontSize + 13

        Label {
            id: words

            text: button.text
        }

        Rectangle {
            parent: button
            visible: button.isDefault
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.color: Colors.deep
        }
    }
}
