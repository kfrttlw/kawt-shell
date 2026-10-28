import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils

// The machine, like a thinkpad's bios setup:
//
//   [main]  power
//
//   ██ ▄█▀  ▀▀▀█▄ ██    ██ ▀██▀▀         ThinkPad T14s Gen 1
//   ██▀█▄  ▄█▀▀██ ██▄██▄██  ██    ▄▄     20T0S0... · kawt bios 1.0
//
//   bios version ........ R1CET73W (1.42)
//   cpu ................. AMD Ryzen 7 PRO 4750U · 16 threads
//   memory .............. 16 GB · 9.8 used
//   battery ............. 72% · health 87% · 312 cycles
//   ...
//   ──────────────────────────────────────────────
//   [lock] [sleep] [logout] [reboot] [off]
//
// power: the battery, where it stops charging, the power profile, the keyboard light; each only
// where the machine has it (a pc: the profile and the buttons)
ColumnLayout {
    id: tab

    required property var profile
    readonly property var bat: UPower.displayDevice
    readonly property bool plugged: bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.FullyCharged
    readonly property int keyWidth: 21 // "bios version ........ "

    spacing: Metrics.spacing
    Component.onCompleted: Hardware.refresh()

    // name ............ value
    component Fact: RowLayout {
        id: fact

        property string name
        property string value
        property color tint: Colors.fg

        Layout.fillWidth: true
        visible: value !== ""
        spacing: 0

        Label {
            text: `${fact.name} ${".".repeat(Math.max(2, tab.keyWidth - fact.name.length - 2))} `
            color: Colors.dim
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: fact.value
            color: fact.tint
        }
    }

    // the same with buttons on the right: name ...... [a] [b] [c]   hint
    component Choice: RowLayout {
        id: choice

        property string name
        property var options: [] // [[value, label]]
        property var current
        property string hint
        signal picked(var value)

        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            text: `${choice.name} ${".".repeat(Math.max(2, tab.keyWidth - choice.name.length - 2))}`
            color: Colors.dim
        }

        Repeater {
            model: choice.options

            BracketButton {
                required property var modelData

                label: modelData[1]
                textColor: choice.current === modelData[0] ? Colors.accent : Colors.dim
                onClicked: choice.picked(modelData[0])
            }
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: choice.hint
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }

    Tabs {
        id: page

        Layout.topMargin: Metrics.spacing
        tabs: ["main", "power"]
    }

    // ---------------------------------------------------------------- main
    ColumnLayout {
        Layout.fillWidth: true
        visible: page.current === 0
        spacing: 2

        RowLayout {
            Layout.topMargin: Metrics.spacing
            Layout.bottomMargin: Metrics.spacing
            spacing: Metrics.padding * 2
            opacity: tab.profile.boot > 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }

            // your ~/.face as ascii (profile -> cfg -> look -> picture), or kawt in half blocks
            // with its lit dot red, the same as fastfetch's
            AsciiAvatar {
                id: avatar

                visible: Settings.profileArt === "auto" && available
                cols: tab.profile.wide ? 26 : 18
            }

            Column {
                visible: !avatar.visible

                Repeater {
                    model: ["██ ▄█▀  ▀▀▀█▄ ██    ██ ▀██▀▀", "██▀█▄  ▄█▀▀██ ██▄██▄██  ██    <font color=\"accent\">▄▄</font>", "▀▀  ▀▀  ▀▀▀▀▀  ▀▀  ▀▀    ▀▀▀  <font color=\"accent\">▀▀</font>"]

                    Label {
                        required property string modelData

                        textFormat: Text.StyledText
                        text: modelData.replace(/"accent"/g, `"${Colors.accent}"`)
                        lineHeight: 0.92
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Label {
                    text: SysInfo.model || SysInfo.host || "this machine"
                    font.bold: true
                }

                Label {
                    text: [Hardware.code !== SysInfo.model ? Hardware.code : "", `kawt bios ${Kawt.version}`].filter(s => s).join(" · ")
                    color: Colors.dim
                }
            }
        }

        Fact {
            name: "bios version"
            value: Hardware.bios
        }

        Fact {
            name: "cpu"
            value: SysInfo.cpuModel + (SysInfo.cores > 0 ? ` · ${SysInfo.cores} threads` : "")
        }

        Repeater {
            model: SysInfo.gpus

            Fact {
                required property string modelData

                name: "gpu"
                value: modelData
            }
        }

        Fact {
            name: "memory"
            value: SysInfo.memTotalGb > 0 ? `${SysInfo.memTotalGb.toFixed(0)} GB · ${SysInfo.memUsedGb.toFixed(1)} used` : ""
        }

        Fact {
            name: "disk"
            value: `${Math.round(SysInfo.disk * 100)}% used`
            tint: SysInfo.disk >= 0.9 ? Colors.warn : Colors.fg
        }

        Fact {
            name: "battery"
            value: tab.bat.isLaptopBattery ? [`${Math.round(tab.bat.percentage * 100)}%${tab.plugged ? " on the cable" : ""}`, SysInfo.batHealth > 0 ? `health ${Math.round(SysInfo.batHealth * 100)}%` : "", SysInfo.batCycles >= 0 ? `${SysInfo.batCycles} cycles` : ""].filter(s => s).join(" · ") : ""
        }

        Fact {
            name: "screen"
            value: SysInfo.res
        }

        Fact {
            name: "system"
            value: [SysInfo.os.toLowerCase(), SysInfo.wm].filter(s => s).join(" · ")
        }

        Fact {
            name: "kernel"
            value: SysInfo.kernel
        }

        Fact {
            name: "packages"
            value: SysInfo.pkgs > 0 ? String(SysInfo.pkgs) : ""
        }

        Fact {
            name: "uptime"
            value: Fmt.uptime(SysInfo.uptime)
        }

        Fact {
            name: "user"
            value: `${SysInfo.user}@${SysInfo.host} · ${SysInfo.shell}`
        }
    }

    // ---------------------------------------------------------------- power
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: page.current === 1
        spacing: Metrics.spacing

        Fact {
            name: "battery"
            value: !tab.bat.isLaptopBattery ? "" : `${Math.round(tab.bat.percentage * 100)}%` + (tab.bat.state === UPowerDeviceState.Charging ? ` · charging${tab.bat.timeToFull > 0 ? ` · full in ${Fmt.uptime(tab.bat.timeToFull)}` : ""}` : tab.bat.state === UPowerDeviceState.FullyCharged ? " · full" : tab.bat.timeToEmpty > 0 ? ` · ${Fmt.uptime(tab.bat.timeToEmpty)} left` : "")
        }

        Fact {
            name: "health"
            value: SysInfo.batHealth > 0 ? `${Math.round(SysInfo.batHealth * 100)}% of what it held new` + (SysInfo.batCycles >= 0 ? ` · ${SysInfo.batCycles} cycles` : "") : ""
            tint: SysInfo.batHealth > 0 && SysInfo.batHealth < 0.6 ? Colors.warn : Colors.fg
        }

        // where it stops charging (pkexec asks for the password)
        Choice {
            visible: Hardware.battery !== ""
            name: "charge up to"
            options: [[100, "full"], [80, "80%"], [60, "60%"]]
            current: Hardware.chargeEnd >= 95 ? 100 : Hardware.chargeEnd
            hint: Hardware.chargeEnd > 0 && Hardware.chargeEnd < 95 ? "lives longer · asks for your password" : "on the cable all day: 60-80% lives longer"
            onPicked: v => Hardware.setCharge(v - 5, v)
        }

        Choice {
            visible: Hardware.profile !== ""
            name: "power"
            options: [["power-saver", "saver"], ["balanced", "balanced"], ["performance", "performance"]]
            current: Hardware.profile
            onPicked: v => Hardware.setProfile(v)
        }

        Choice {
            visible: Hardware.kbd !== ""
            name: "keyboard light"
            options: Array.from({ length: Math.min(Hardware.kbdMax, 3) + 1 }, (_, i) => [i, i === 0 ? "off" : String(i)])
            current: Hardware.kbdLevel
            onPicked: v => Hardware.setKbd(v)
        }

        Label {
            visible: Hardware.status !== ""
            text: Hardware.status
            color: Colors.warn
        }

        Label {
            visible: !tab.bat.isLaptopBattery && Hardware.profile === ""
            text: "-- no battery and no power profiles here --"
            color: Colors.dim
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    // the way out, like a bios's exit page: a second click for the ones that end the session
    RowLayout {
        spacing: Metrics.spacing
        opacity: tab.profile.boot > 2 ? 1 : 0

        BracketButton {
            label: "lock"
            onClicked: tab.profile.power("lock", [])
        }

        BracketButton {
            label: "sleep"
            onClicked: tab.profile.power("sleep", [])
        }

        BracketButton {
            label: tab.profile.armed === "logout" ? "sure?" : "logout"
            textColor: tab.profile.armed === "logout" ? Colors.warn : Colors.fg
            onClicked: tab.profile.power("logout", [])
        }

        BracketButton {
            label: tab.profile.armed === "reboot" ? "sure?" : "reboot"
            textColor: tab.profile.armed === "reboot" ? Colors.warn : Colors.fg
            onClicked: tab.profile.power("reboot", ["systemctl", "reboot"])
        }

        BracketButton {
            label: tab.profile.armed === "off" ? "sure?" : "off"
            textColor: tab.profile.armed === "off" ? Colors.warn : Colors.fg
            onClicked: tab.profile.power("off", ["systemctl", "poweroff"])
        }
    }
}
