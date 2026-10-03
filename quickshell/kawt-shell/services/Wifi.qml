pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// Thin layer over Quickshell.Networking (NetworkManager backend)
Singleton {
    id: root

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool enabled: Networking.wifiEnabled
    readonly property var networks: device?.networks.values ?? []
    readonly property var active: networks.find(n => n.connected) ?? null

    // Connected first, then by signal; hidden (unnamed) networks dropped
    readonly property var sorted: networks.filter(n => n.name).sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))

    property bool scanning: false

    function signalBars(strength: real): string {
        const n = Math.round(Math.max(0, Math.min(1, strength)) * 4);
        return "▂▄▆█".slice(0, n) + "_".repeat(4 - n);
    }

    function isSecure(net: var): bool {
        return net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Owe;
    }

    function setEnabled(on: bool): void {
        Networking.wifiEnabled = on;
    }

    Binding {
        when: root.device !== null
        target: root.device
        property: "scannerEnabled"
        value: root.scanning
    }
}
