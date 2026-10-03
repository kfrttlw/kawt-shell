import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils

// battery details and the power profile:
//   [###############-----]  72%
//   discharging · 3h 12m left · -8.4 W
//   health 81% · 324 cycles · charge stops at 80%
//   [saver] balanced  perf
Popover {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool charging: dev.state === UPowerDeviceState.Charging
    readonly property bool full: dev.state === UPowerDeviceState.FullyCharged
    readonly property bool plugged: charging || full || dev.state === UPowerDeviceState.PendingCharge

    name: "battery"
    title: "battery"
    cardWidth: 320

    Label {
        Layout.topMargin: Metrics.spacing
        text: `[${Fmt.bar(root.dev.percentage, 22)}] ${Math.round(root.dev.percentage * 100)}%`
        color: !root.plugged && root.dev.percentage < 0.15 ? Colors.warn : Colors.fg
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: [
            root.full ? "full" : root.charging ? "charging" : root.plugged ? "plugged in, not charging" : "discharging",
            root.charging && root.dev.timeToFull > 0 ? `${Fmt.uptime(root.dev.timeToFull)} to full` : "",
            !root.plugged && root.dev.timeToEmpty > 0 ? `${Fmt.uptime(root.dev.timeToEmpty)} left` : "",
            Math.abs(root.dev.changeRate) >= 0.1 ? `${root.plugged ? "+" : "-"}${Math.abs(root.dev.changeRate).toFixed(1)} W` : ""
        ].filter(s => s).join(" · ")
        color: Colors.dim
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        visible: text !== ""
        text: [
            SysInfo.batHealth > 0 ? `health ${Math.round(SysInfo.batHealth * 100)}%` : "",
            SysInfo.batCycles > 0 ? `${SysInfo.batCycles} cycles` : "",
            SysInfo.batLimit > 0 && SysInfo.batLimit < 100 ? `charge stops at ${SysInfo.batLimit}%` : "",
            root.dev.energyCapacity > 0 ? `${root.dev.energy.toFixed(1)}/${root.dev.energyCapacity.toFixed(1)} Wh` : ""
        ].filter(s => s).join(" · ")
        color: Colors.dim
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    // power-profiles-daemon; the selected one is in [brackets]
    Label {
        text: "power profile"
        color: Colors.dim
    }

    RowLayout {
        spacing: Metrics.spacing

        Repeater {
            model: [
                { name: "saver", profile: PowerProfile.PowerSaver },
                { name: "balanced", profile: PowerProfile.Balanced },
                { name: "perf", profile: PowerProfile.Performance }
            ]

            BracketButton {
                required property var modelData

                visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                label: modelData.name
                active: PowerProfiles.profile === modelData.profile
                textColor: PowerProfiles.profile === modelData.profile ? Colors.accent : Colors.fg
                onClicked: PowerProfiles.profile = modelData.profile
            }
        }
    }
}
