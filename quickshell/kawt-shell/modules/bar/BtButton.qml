import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import qs.config
import qs.components

// [bt off] · [bt on] · [bt airpods 80%] (one connected) · [bt 2] (several)
// [bt --]: the machine has bluetooth, but the bluetooth service (bluez) isn't running;
// the panel says how to start it
BracketButton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
    property bool hardware: false

    visible: adapter !== null || hardware
    tag: "bt"
    label: adapter === null ? "--"
        : !adapter.enabled ? "off"
        : connected.length === 0 ? "on"
        : connected.length > 1 ? String(connected.length)
        : (connected[0].name.length > 12 ? connected[0].name.slice(0, 11) + "~" : connected[0].name).toLowerCase()
            + (connected[0].batteryAvailable ? ` ${Math.round(connected[0].battery * 100)}%` : "")
    textColor: adapter?.enabled ? (connected.length > 0 ? Colors.accent : Colors.fg) : Colors.dim

    // is there a bluetooth chip at all? (then the button stays, even with the service off)
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/bluetooth 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: root.hardware = text.trim() !== ""
        }
    }
}
