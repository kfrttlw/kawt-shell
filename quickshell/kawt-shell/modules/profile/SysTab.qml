import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils
import "../popovers"

ColumnLayout {
    required property var profile

    // a titled box for the sys tab: ┌─cpu───── 42%┐
    component Card: TitledBox {
        id: card

        property bool warn: false
        default property alias content: cardBody.data

        Layout.fillWidth: true
        Layout.preferredWidth: 1 // equal widths
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: titleOverhang
        implicitHeight: cardBody.implicitHeight + Metrics.padding * 2 + titleOverhang
        border.color: warn ? Colors.warn : Colors.border

        ColumnLayout {
            id: cardBody

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + card.titleOverhang
            spacing: 4
        }
    }

    spacing: Metrics.spacing

    // header
    RowLayout {
        Layout.topMargin: Metrics.spacing
        Layout.fillWidth: true
        spacing: Metrics.padding * 2
        opacity: profile.boot > 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        AsciiAvatar {
            id: avatar

            Layout.alignment: Qt.AlignTop
            visible: Settings.profileArt === "auto" && available
            cols: profile.wide ? 30 : 22
        }

        DeviceArt {
            Layout.alignment: Qt.AlignTop
            visible: !avatar.visible
            laptop: SysInfo.laptop
            blink: profile.open
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.alignment: Qt.AlignTop
            spacing: 2

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `${SysInfo.user}@${SysInfo.host}`
                color: Colors.accent
                font.pixelSize: Math.round(Metrics.fontSize * 1.6)
                font.bold: true
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: [SysInfo.os.toLowerCase(), SysInfo.model.replace(/^ThinkPad /, "tp "), SysInfo.wm].filter(s => s).join(" · ")
                color: Colors.dim
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `up ${Fmt.uptime(SysInfo.uptime)} · ${Qt.formatDate(Time.now, "ddd dd.MM").toLowerCase()} · ${Time.fmt(Time.now)}`
                color: Colors.dim
            }

            // the motto: a line of your own, or a fortune each time the profile opens
            Label {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                visible: text !== ""
                elide: Text.ElideRight
                text: Settings.motto === "" ? "" : `> ${Settings.motto === "fortune" ? profile.fortune : Settings.motto}`
                color: Colors.fg
            }
        }
    }

    // cards
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        spacing: Metrics.spacing
        opacity: profile.boot > 1 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        Card {
            title: "cpu"
            hint: `${Math.round(SysInfo.cpu * 100)}%`
            warn: SysInfo.cpuTemp >= 85

            BarGraph {
                Layout.fillWidth: true
                values: SysInfo.cpuHistory.slice(profile.wide ? -40 : -24)
                barColor: SysInfo.cpuTemp >= 85 ? Colors.warn : Colors.accent
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: [SysInfo.cpuTemp >= 0 ? `${Math.round(SysInfo.cpuTemp)}°C` : "", SysInfo.fan > 0 ? `${SysInfo.fan} rpm` : SysInfo.fan === 0 ? "fan idle" : "", SysInfo.load ? `load ${SysInfo.load.split(" ")[0]}` : ""].filter(s => s).join(" · ")
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }
        }

        Card {
            title: "mem"
            hint: `${Math.round(SysInfo.mem * 100)}%`

            BarGraph {
                Layout.fillWidth: true
                values: SysInfo.memHistory.slice(profile.wide ? -40 : -24)
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `${SysInfo.memUsedGb.toFixed(1)}/${SysInfo.memTotalGb.toFixed(0)}G` + (SysInfo.swapTotalGb > 0 ? ` · swap ${(SysInfo.swap * SysInfo.swapTotalGb).toFixed(1)}G` : "")
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }
        }

        Card {
            title: "today"
            hint: Todo.open > 0 ? `${Todo.open} open` : ""

            Label {
                visible: profile.upcoming.length === 0
                text: "-- free day --"
                color: Colors.dim
            }

            Repeater {
                model: profile.upcoming.slice(0, 3)

                Label {
                    required property var modelData

                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: `${modelData.due ? Time.fmt(new Date(modelData.due)) : "  -  "}  ${modelData.text}`
                    color: modelData.due && modelData.due < Time.now.getTime() ? Colors.warn : Colors.fg
                }
            }

            Label {
                Layout.fillWidth: true
                visible: profile.next !== null
                elide: Text.ElideRight
                text: profile.next ? `next in ${profile.until(profile.next.due)}` : ""
                color: Colors.accent
                font.pixelSize: Metrics.fontSize - 2
            }
        }
    }

    // one status line
    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        opacity: profile.boot > 2 ? 1 : 0
        text: {
            const dev = UPower.displayDevice;
            const plugged = dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged;
            return [
                `net ↓${Fmt.rate(NetStats.rx).trim()} ↑${Fmt.rate(NetStats.tx).trim()}`,
                `disk ${Math.round(SysInfo.disk * 100)}%`,
                dev.isLaptopBattery ? `bat ${Math.round(dev.percentage * 100)}%${plugged ? "+" : ""}` + (!plugged && dev.timeToEmpty > 0 ? ` ${Fmt.uptime(dev.timeToEmpty)} left` : "") : "",
                SysInfo.pkgs > 0 ? `${SysInfo.pkgs} pkgs` : ""
            ].filter(s => s).join(" · ");
        }
        color: Colors.dim

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }
    }

    // the rest of the neofetch facts, small
    Flow {
        Layout.fillWidth: true
        spacing: Metrics.padding
        opacity: profile.boot > 3 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        Repeater {
            model: [
                ["cpu", SysInfo.cpuModel + (SysInfo.cores > 0 ? ` (${SysInfo.cores})` : "")],
                ...SysInfo.gpus.map(g => ["gpu", g]),
                ["kern", SysInfo.kernel],
                ["shell", SysInfo.shell],
                ["res", SysInfo.res]
            ].filter(r => r[1])

            Row {
                required property var modelData

                spacing: 4

                Label {
                    text: modelData[0]
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }

                Label {
                    text: modelData[1]
                    font.pixelSize: Metrics.fontSize - 2
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        opacity: profile.boot > 4 ? 1 : 0
        spacing: Metrics.spacing

        BracketButton {
            label: "lock"
            onClicked: profile.power("lock", [])
        }

        BracketButton {
            label: "sleep"
            onClicked: profile.power("sleep", [])
        }

        // caffeine: no idle lock, the screen stays on
        BracketButton {
            label: "caf"
            active: Idle.caffeine
            textColor: Idle.caffeine ? Colors.accent : Colors.fg
            onClicked: Idle.caffeine = !Idle.caffeine
        }

        BracketButton {
            label: profile.armed === "logout" ? "sure?" : "logout"
            textColor: profile.armed === "logout" ? Colors.warn : Colors.fg
            onClicked: profile.power("logout", [])
        }

        BracketButton {
            label: profile.armed === "reboot" ? "sure?" : "reboot"
            textColor: profile.armed === "reboot" ? Colors.warn : Colors.fg
            onClicked: profile.power("reboot", ["systemctl", "reboot"])
        }

        BracketButton {
            label: profile.armed === "off" ? "sure?" : "off"
            textColor: profile.armed === "off" ? Colors.warn : Colors.fg
            onClicked: profile.power("off", ["systemctl", "poweroff"])
        }
    }
}
