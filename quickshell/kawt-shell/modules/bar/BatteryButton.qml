import Quickshell.Services.UPower
import qs.config
import qs.components

BracketButton {
    readonly property var device: UPower.displayDevice
    readonly property bool charging: device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.FullyCharged
        || device.state === UPowerDeviceState.PendingCharge

    visible: device.isLaptopBattery
    tag: "bat"
    label: `${Math.round(device.percentage * 100)}%${charging ? "+" : ""}`
    textColor: !charging && device.percentage < 0.2 ? Colors.warn : Colors.fg
}
