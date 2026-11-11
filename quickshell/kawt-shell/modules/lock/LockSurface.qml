import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils

// The lock, switched on like an old picture tube (and off again into a line when the password
// is right). A, the default: an old system's log-on window over the wallpaper dimmed with dots,
//
//   ┌ ⚿ Log on to kawt ──────────────────────────────┐
//   │ ⚿  The computer is locked. Type your password.  │
//   │    User:      [user               ]             │
//   │    Password:  [••••••█            ]             │
//   │    ⚠ Caps Lock is on                            │
//   │                   [ OK ] [ Sleep ] [Shut down…] │
//   └─────────────────────────────────────────────────┘
// B (settings -> screen and lock -> the lock's look): a text console at its login:
//
//   Arch Linux 6.18.44-1 (kawt-lock)                                    kawt■
//
//   host login: user
//   Password: ••••••█
//   [!] access denied (1)
//
//
//   [us] bat 72% 3h left · 54°C · wifi home · 2 messages                 14:32
//   next: today 15:00  dentist                                   tue 28.10.2026
//   portishead — roads   [<<] [||] [>>]
// (who you are, the wifi, messages, the next task and the music only with Settings.lockDetails:
// anyone at the screen sees them)
WlSessionLockSurface {
    id: root

    required property var lockScope
    readonly property int margin: Math.round(Metrics.fontSize * 3.5)
    // B, the console, by choice (settings -> screen and lock); A, the log-on window, otherwise
    readonly property bool consoleLook: Settings.lockLook === "console"
    property bool askOff: false // "Shut down…" pressed: which one, or cancel

    // the field the password goes in, in the look that's on
    function focusField(): void {
        (consoleLook ? password : windowPassword).input.forceActiveFocus();
    }

    function tryUnlock(t: string): void {
        root.lockScope.tryUnlock(t);
        password.text = "";
        windowPassword.text = "";
    }

    color: Colors.bg

    Connections {
        target: root.lockScope

        function onLeavingChanged(): void {
            if (root.lockScope.leaving)
                tube.turnOff();
        }
    }

    CrtTube {
        id: tube

        anchors.fill: parent
        onOffDone: root.lockScope.unlock()

        // ---- B · the console (Settings.lockLook "console")
        Item {
            anchors.fill: parent
            visible: root.consoleLook

            // the wallpaper, barely there, like a picture burned into an old CRT
            Image {
                anchors.fill: parent
                source: Wallpapers.shown ? `file://${Wallpapers.shown}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: !Settings.wallDither
                sourceSize.width: 1280
                opacity: 0.12
            }

            // clicking anywhere gives the keyboard back to the password field
            MouseArea {
                anchors.fill: parent
                onClicked: root.focusField()
            }

            // ---- top left: the console's login
            ColumnLayout {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: root.margin
                width: Math.min(560, parent.width - root.margin * 2)
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: `${[SysInfo.os, SysInfo.kernel].filter(s => s).join(" ") || "kawt"} (kawt-lock)`
                    color: Colors.dim
                }

                Item {
                    implicitHeight: Metrics.fontSize
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Settings.lockDetails ? `${SysInfo.host || "kawt"} login: ${SysInfo.user}` : "login: locked"
                }

                TermInput {
                    id: password

                    Layout.fillWidth: true
                    framed: false
                    prompt: "Password:"
                    promptColor: Colors.fg
                    placeholder: "type to unlock"
                    echoMode: TextInput.Password
                    onAccepted: t => root.tryUnlock(t)

                    Keys.onEscapePressed: password.text = ""
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_CapsLock)
                            Keyboard.checkCaps();
                    }
                }

                // the most common reason a right password is "wrong"
                Label {
                    Layout.fillWidth: true
                    visible: Keyboard.caps
                    text: "[!] caps lock is on"
                    color: Colors.warn
                }

                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    text: root.lockScope.status === "" ? "" : (root.lockScope.result === "checking" ? "" : "[!] ") + root.lockScope.status
                    color: root.lockScope.result === "checking" ? Colors.dim : Colors.warn
                }

                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacing
                    visible: root.lockScope.testLeft > 0
                    text: `-- test mode: unlocks by itself in ${root.lockScope.testLeft}s --`
                    color: Colors.dim
                }
            }

            // ---- top right: kawt and its lit dot
            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: root.margin
                spacing: 2

                Label {
                    text: "kawt"
                    font.pixelSize: Metrics.times(1.5)
                    font.bold: !Metrics.pixel
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(Metrics.fontSize * 0.35)
                    width: Math.round(Metrics.fontSize * 0.55)
                    height: width
                    color: Colors.accent
                }
            }

            // ---- bottom left: what you'd otherwise unlock for
            ColumnLayout {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: root.margin
                width: Math.min(620, parent.width - clock.width - root.margin * 3)
                spacing: 2

                //   [us]  bat 72% 3h left · 54°C · wifi home · 2 messages
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacing

                    // the layout you're typing the password in; click to switch
                    LabelButton {
                        visible: Keyboard.code !== ""
                        label: Keyboard.code
                        onClicked: Keyboard.next()
                    }

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: {
                            const dev = UPower.displayDevice;
                            const plugged = dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged;
                            return [
                                dev.isLaptopBattery ? `bat ${Math.round(dev.percentage * 100)}%${plugged ? "+" : ""}` + (!plugged && dev.timeToEmpty > 0 ? ` ${Fmt.uptime(dev.timeToEmpty)} left` : "") : "",
                                SysInfo.cpuTemp >= 0 ? `${Math.round(SysInfo.cpuTemp)}°C` : "",
                                Wifi.active && Settings.lockDetails ? `wifi ${Wifi.active.name}` : "",
                                Notifs.count > 0 && Settings.lockDetails ? `${Notifs.count} message${Notifs.count === 1 ? "" : "s"}` : ""
                            ].filter(s => s).join(" · ");
                        }
                        color: Colors.dim
                    }
                }

                // the next timed task
                Label {
                    Layout.fillWidth: true
                    readonly property var next: Todo.sorted.find(t => !t.done && t.due > Time.now.getTime()) ?? null
                    visible: next !== null && Settings.lockDetails
                    elide: Text.ElideRight
                    text: next ? `next: ${Todo.when(next.due)}  ${next.text}` : ""
                }

                // now playing, with controls
                RowLayout {
                    id: media

                    readonly property var player: Media.player

                    Layout.fillWidth: true
                    visible: player !== null && Settings.lockDetails
                    spacing: Metrics.spacing

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: [media.player?.trackArtist, media.player?.trackTitle].filter(s => s).join(" — ") || media.player?.identity || ""
                        color: Colors.dim
                    }

                    LabelButton {
                        label: "<<"
                        onClicked: media.player?.previous()
                    }

                    LabelButton {
                        label: media.player?.isPlaying ? "||" : ">"
                        textColor: media.player?.isPlaying ? Colors.accent : Colors.fg
                        onClicked: media.player?.togglePlaying()
                    }

                    LabelButton {
                        label: ">>"
                        onClicked: media.player?.next()
                    }
                }
            }

            // ---- bottom right: the time, big
            ColumnLayout {
                id: clock

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: root.margin
                spacing: 0

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: Time.fmt(Time.now)
                    font.pixelSize: Metrics.times(6)
                    font.weight: Font.Light
                }

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDate(Time.now, "dddd · dd MMM yyyy").toLowerCase()
                    color: Colors.dim
                }
            }
        }

        // ---- A · the log-on window (the default)
        Item {
            anchors.fill: parent
            visible: !root.consoleLook

            // the wallpaper, dimmed with dots
            Image {
                anchors.fill: parent
                source: Wallpapers.shown ? `file://${Wallpapers.shown}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: !Settings.wallDither
                sourceSize.width: 1920
            }

            Dots {
                anchors.fill: parent
                base: "transparent"
                dots: Qt.rgba(0, 0, 0, 0.85)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.focusField()
            }

            KWindow {
                id: logon

                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)
                width: Math.round(470 * Metrics.scale)
                height: chrome + logonBody.implicitHeight
                title: Strings.t("lockTitle")
                icon: "key"
                closable: false

                RowLayout {
                    id: logonBody

                    width: parent.width
                    spacing: 12

                    PixIcon {
                        Layout.alignment: Qt.AlignTop
                        size: 32
                        name: "key"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: Strings.t("lockAsk")
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 6

                            Label {
                                text: Strings.t("lockUser")
                            }

                            // who it is: shown, not typed (anyone at the screen sees it: with
                            // Settings.lockDetails only)
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: windowPassword.implicitHeight
                                color: Colors.well

                                Bevel {
                                    style: "sunk"
                                }

                                Label {
                                    x: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Settings.lockDetails ? SysInfo.user : "••••"
                                    color: Settings.lockDetails ? Colors.fg : Colors.dim
                                }
                            }

                            Label {
                                text: Strings.t("lockPassword")
                            }

                            TermInput {
                                id: windowPassword

                                Layout.fillWidth: true
                                prompt: ""
                                echoMode: TextInput.Password
                                onAccepted: t => root.tryUnlock(t)

                                Keys.onEscapePressed: windowPassword.text = ""
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_CapsLock)
                                        Keyboard.checkCaps();
                                }
                            }
                        }

                        // the most common reason a right password is "wrong"
                        RowLayout {
                            visible: Keyboard.caps
                            spacing: 6

                            PixIcon {
                                name: "warn"
                            }

                            Label {
                                text: Strings.t("capsOn")
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            text: root.lockScope.status
                            color: root.lockScope.result === "checking" ? Colors.dim : Colors.warn
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: root.lockScope.testLeft > 0
                            text: Strings.t("lockTest").arg(root.lockScope.testLeft)
                            color: Colors.dim
                        }

                        // OK · Sleep · Shut down… (that one asks which, here: the shut down
                        // dialog is under the lock)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 4

                            // the layout the password is typed in; a click switches it
                            PushButton {
                                visible: Keyboard.code !== ""
                                minWidth: 0
                                text: Keyboard.code
                                onClicked: Keyboard.next()
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            PushButton {
                                visible: !root.askOff
                                text: Strings.t("ok")
                                onClicked: root.tryUnlock(windowPassword.text)
                            }

                            PushButton {
                                visible: !root.askOff
                                text: Strings.t("suspend")
                                onClicked: Panels.suspend()
                            }

                            PushButton {
                                visible: !root.askOff
                                minWidth: 0
                                text: Strings.t("shutdownDots")
                                onClicked: root.askOff = true
                            }

                            PushButton {
                                visible: root.askOff
                                minWidth: 0
                                text: Strings.t("powerOff")
                                onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                            }

                            PushButton {
                                visible: root.askOff
                                minWidth: 0
                                text: Strings.t("reboot")
                                onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                            }

                            PushButton {
                                visible: root.askOff
                                text: Strings.t("cancel")
                                onClicked: {
                                    root.askOff = false;
                                    root.focusField();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        tube.turnOn();
        root.focusField();
        Keyboard.checkCaps();
    }
}
