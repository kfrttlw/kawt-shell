import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils

// The lock as a text console at its login, switched on like an old picture tube (and off
// again into a line when the password is right):
//
//   Arch Linux 6.18.44-1 (kawt-lock)                                    kawt■
//
//   t480 login: kfrtl
//   Password: ••••••█
//   [!] access denied (1)
//
//
//   [us] bat 72% 3h left · 54°C · wifi home · 2 messages                 14:32
//   next: today 15:00  dentist                                   tue 28.10.2026
//   massive attack — teardrop   [<<] [||] [>>]
// (who you are, the wifi, messages, the next task and the music only with Settings.lockDetails:
// anyone at the screen sees them)
WlSessionLockSurface {
    id: root

    required property var lockScope
    readonly property int margin: Math.round(Metrics.fontSize * 3.5)

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
            onClicked: password.input.forceActiveFocus()
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
                onAccepted: t => {
                    root.lockScope.tryUnlock(t);
                    password.text = "";
                }

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
                text: root.lockScope.status === "" ? "" : (root.lockScope.status.startsWith("checking") ? "" : "[!] ") + root.lockScope.status
                color: root.lockScope.status.startsWith("checking") ? Colors.dim : Colors.warn
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
                font.pixelSize: Math.round(Metrics.fontSize * 1.5)
                font.bold: true
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
                BracketButton {
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

                BracketButton {
                    label: "<<"
                    onClicked: media.player?.previous()
                }

                BracketButton {
                    label: media.player?.isPlaying ? "||" : ">"
                    textColor: media.player?.isPlaying ? Colors.accent : Colors.fg
                    onClicked: media.player?.togglePlaying()
                }

                BracketButton {
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
                font.pixelSize: Metrics.fontSize * 6
                font.weight: Font.Light
            }

            Label {
                Layout.alignment: Qt.AlignRight
                text: Qt.formatDate(Time.now, "dddd · dd MMM yyyy").toLowerCase()
                color: Colors.dim
            }
        }
    }

    Component.onCompleted: {
        tube.turnOn();
        password.input.forceActiveFocus();
        Keyboard.checkCaps();
    }
}
