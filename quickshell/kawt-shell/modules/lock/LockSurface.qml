import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils
import "../popovers"

//   ____________
//  | >_         |
//  ...                         12:34
//                       sat 03.10.2026
//  kawt-lock on tty · user@host
//  password: ********█
//  [!] access denied (1)
WlSessionLockSurface {
    id: root

    required property var lockScope

    color: Colors.bg

    // the wallpaper, barely there, like a picture burned into an old CRT
    Image {
        anchors.fill: parent
        source: Settings.wallpaper ? `file://${Settings.wallpaper}` : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 1280
        opacity: 0.12
    }

    // clicking anywhere gives the keyboard back to the password field
    MouseArea {
        anchors.fill: parent
        onClicked: password.input.forceActiveFocus()
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(460, root.width - 40)
        spacing: Metrics.spacing

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Metrics.padding * 2

            DeviceArt {
                laptop: SysInfo.laptop
                blink: true
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignBottom
                spacing: 0

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: Time.fmt(Time.now)
                    font.pixelSize: Metrics.fontSize * 4
                }

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDate(Time.now, "ddd dd.MM.yyyy").toLowerCase()
                    color: Colors.dim
                }
            }
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: `kawt-lock · ${SysInfo.user}@${SysInfo.host}`
            color: Colors.accent
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Metrics.borderWidth
            color: Colors.border
        }

        TermInput {
            id: password

            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            prompt: "password:"
            placeholder: "type to unlock"
            echoMode: TextInput.Password
            onAccepted: t => {
                root.lockScope.tryUnlock(t);
                password.text = "";
            }

            Keys.onEscapePressed: password.text = ""
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.Wrap
            text: root.lockScope.status === "" ? "" : (root.lockScope.status.startsWith("checking") ? "" : "[!] ") + root.lockScope.status
            color: root.lockScope.status.startsWith("checking") ? Colors.dim : Colors.warn
        }

        // what you'd otherwise unlock for: layout, battery, heat, wifi, messages
        //   [us]  bat 72% 3h left · 54°C · wifi home · 2 messages
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            spacing: Metrics.spacing

            // the layout you're typing the password in; click to switch
            BracketButton {
                visible: Keyboard.code !== ""
                label: Keyboard.code
                textColor: Colors.accent
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
                        Wifi.active ? `wifi ${Wifi.active.name}` : "",
                        Notifs.count > 0 ? `${Notifs.count} message${Notifs.count === 1 ? "" : "s"}` : ""
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
            color: Colors.fg
        }

        // now playing, with controls
        RowLayout {
            readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

            id: media

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
                bordered: false
                onClicked: media.player?.previous()
            }

            BracketButton {
                label: media.player?.isPlaying ? "||" : ">"
                bordered: false
                onClicked: media.player?.togglePlaying()
            }

            BracketButton {
                label: ">>"
                bordered: false
                onClicked: media.player?.next()
            }
        }

        Label {
            Layout.fillWidth: true
            visible: root.lockScope.testLeft > 0
            text: `-- test mode: unlocks by itself in ${root.lockScope.testLeft}s --`
            color: Colors.dim
        }
    }

    Component.onCompleted: password.input.forceActiveFocus()
}
