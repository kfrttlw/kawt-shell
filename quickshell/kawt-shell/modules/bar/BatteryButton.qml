import QtQuick
import Quickshell.Services.UPower
import qs.config
import qs.components
import "../../utils/pixicons.js" as Pix

// only on a laptop: how full, a bolt while charging, red when low
BarIcon {
    readonly property var device: UPower.displayDevice
    readonly property bool charging: device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged || device.state === UPowerDeviceState.PendingCharge
    readonly property int pct: Math.round(device.percentage * 100)

    visible: Settings.barShows("bat") && device.isLaptopBattery
    icon: Pix.battery(device.percentage, charging)
    tip: Strings.t(charging ? "charging" : "battery").arg(pct)
}
