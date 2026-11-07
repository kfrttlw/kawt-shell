import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import qs.config
import qs.components

// [bt off] · [bt on] · [bt airpods 80%] (one connected) · [bt 2] (several)
// [bt --]: the machine has bluetooth, but the bluetooth service (bluez) isn't running;
// the panel says how to start it
BarIcon {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
    property bool hardware: false

    visible: Settings.barShows("bt") && (adapter !== null || hardware) && (connected.length > 0 || Settings.btAlways)
    // only with a device connected: the bluetooth panel is in the start menu's system otherwise
    icon: "bt"
    tip: connected.length === 0 ? Strings.t("bluetooth") : `${Strings.t("bluetooth")}: ${connected.map(d => d.name + (d.batteryAvailable ? ` ${Math.round(d.battery * 100)}%` : "")).join(", ")}`

    // is there a bluetooth chip at all? (then the button stays, even with the service off)
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/bluetooth 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: root.hardware = text.trim() !== ""
        }
    }
}
