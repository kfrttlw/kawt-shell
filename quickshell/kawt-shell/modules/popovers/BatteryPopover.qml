import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils
import "../../utils/pixicons.js" as Pix

// The power, the old way: the battery big, how long it lasts; the power profile and where the
// charging stops, one of a few each; the screen's brightness and the night light under them.
//
//   [▮▮▮ ]  72%
//           3 h 10 min left · on battery
//   ┌ Mode ─────────────────────────────┐
//   │ ( ) Quiet  (•) Balanced  ( ) Fast  │
//   └────────────────────────────────────┘
//   ┌ Charge up to ──────────────────────┐
//   │ ( ) 100%  (•) 80%  ( ) 60%          │
//   └────────────────────────────────────┘
//   ☼ ──────■──── 60%
//   [x] Night light · warmer after sunset
Popover {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool charging: dev.state === UPowerDeviceState.Charging
    readonly property bool full: dev.state === UPowerDeviceState.FullyCharged
    readonly property bool plugged: charging || full || dev.state === UPowerDeviceState.PendingCharge

    name: "battery"
    title: Strings.t("tab_power")
    icon: Pix.battery(dev.percentage, charging)
    cardWidth: 360
    settingsPage: "screen"
    onPanelOpened: Hardware.refresh() // where the charging stops, as the machine says now

    // a pc has none of it: no battery, maybe no power profiles; what isn't there isn't shown
    // (the bar has no battery button there at all: modules/bar/BatteryButton.qml)
    Label {
        visible: !root.dev.isLaptopBattery
        text: Strings.t("noBattery")
        color: Colors.dim
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.dev.isLaptopBattery
        spacing: Metrics.padding

        PixIcon {
            size: 32
            name: Pix.battery(root.dev.percentage, root.charging)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                text: `${Math.round(root.dev.percentage * 100)}%`
                font.pixelSize: Metrics.fontSize * 2
                color: !root.plugged && root.dev.percentage < 0.15 ? Colors.warn : Colors.fg
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: [
                    root.charging && root.dev.timeToFull > 0 ? Strings.t("batFullIn").arg(Fmt.uptime(root.dev.timeToFull)) : "",
                    !root.plugged && root.dev.timeToEmpty > 0 ? Strings.t("batLeft").arg(Fmt.uptime(root.dev.timeToEmpty)) : "",
                    root.full ? Strings.t("batFull") : root.charging ? Strings.t("batCharging") : root.plugged ? Strings.t("batPlugged") : Strings.t("batOnBattery")
                ].filter(s => s).join(" · ")
                color: Colors.dim
            }
        }
    }

    // health, cycles, energy: one dim line
    Label {
        Layout.fillWidth: true
        visible: root.dev.isLaptopBattery && text !== ""
        elide: Text.ElideRight
        text: [
            SysInfo.batHealth > 0 ? Strings.t("batHealth").arg(Math.round(SysInfo.batHealth * 100)) : "",
            SysInfo.batCycles > 0 ? Strings.count(SysInfo.batCycles, "cycle") : "",
            root.dev.energyCapacity > 0 ? `${root.dev.energy.toFixed(1)}/${root.dev.energyCapacity.toFixed(1)} Wh` : "",
            Math.abs(root.dev.changeRate) >= 0.1 ? `${root.plugged ? "+" : "−"}${Math.abs(root.dev.changeRate).toFixed(1)} W` : ""
        ].filter(s => s).join(" · ")
        color: Colors.dim
    }

    // power-profiles-daemon, if it runs (Hardware.profile: "" without it)
    Group {
        visible: Hardware.profile !== ""
        title: Strings.t("powerMode")

        RowLayout {
            spacing: Metrics.padding

            Repeater {
                model: [
                    { key: "modeQuiet", profile: PowerProfile.PowerSaver },
                    { key: "modeBalanced", profile: PowerProfile.Balanced },
                    { key: "modeFast", profile: PowerProfile.Performance }
                ]

                Check {
                    required property var modelData

                    visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                    radio: true
                    text: Strings.t(modelData.key)
                    checked: PowerProfiles.profile === modelData.profile
                    onToggled: PowerProfiles.profile = modelData.profile
                }
            }
        }
    }

    // where the charging stops (pkexec asks for the password), where the machine lets it be set
    Group {
        visible: Hardware.battery !== ""
        title: Strings.t("chargeUpTo")

        RowLayout {
            spacing: Metrics.padding

            Repeater {
                model: [100, 80, 60]

                Check {
                    required property int modelData

                    radio: true
                    text: `${modelData}%`
                    checked: (Hardware.chargeEnd >= 95 ? 100 : Hardware.chargeEnd) === modelData
                    onToggled: Hardware.setCharge(modelData - 5, modelData)
                }
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Strings.t("chargeNote")
            color: Colors.dim
        }

        Label {
            Layout.fillWidth: true
            visible: Hardware.status !== ""
            wrapMode: Text.Wrap
            text: Hardware.status
            color: Colors.warn
        }
    }

    BrightnessRow {}
}
