pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.utils

// Thin layer over Quickshell.Networking (NetworkManager backend), plus hidden networks
// through nmcli (scripts/wifi-hidden.sh): they don't show up in a scan, so the name is typed
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

    // ---- a hidden network. Here and not in the panel: closing the panel mid-way must not
    // cut nmcli off while it's still handing the password over
    property string hiddenStatus: "" // "connecting to x..." / "connected to x" / "failed: why"
    readonly property bool hiddenBusy: hiddenJob.running

    // psk "" = an open network. The password goes to the script on stdin, never as an argument
    function connectHidden(ssid: string, psk: string): void {
        if (hiddenJob.running || !ssid)
            return;
        hiddenStatus = `connecting to ${ssid}...`;
        hiddenJob.ssid = ssid;
        hiddenJob.input = psk;
        hiddenJob.command = ["sh", `${Quickshell.shellDir}/scripts/wifi-hidden.sh`, ssid];
        hiddenJob.stdinEnabled = true;
        hiddenJob.running = true;
    }

    Job {
        id: hiddenJob

        property string ssid: ""
        property string input: ""

        onStarted: {
            write(input + "\n");
            input = "";
            stdinEnabled = false;
        }
        onDone: (code, out) => root.hiddenStatus = code === 0 ? `connected to ${ssid}` : `failed: ${out.trim().split("\n").pop() || "couldn't connect"}`
    }

    Binding {
        when: root.device !== null
        target: root.device
        property: "scannerEnabled"
        value: root.scanning
    }
}
