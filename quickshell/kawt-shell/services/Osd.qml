pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.utils

// On-screen display for volume and brightness: whatever changes them (media keys, the bar,
// another app), the new level pops up for a moment. Quiet for the first seconds after start,
// so loading the current values doesn't count as a change.
// Also: plugging the charger in / out shows the battery level, and a low battery (20, 10,
// 5%) sends one notification per step. UPower tells us about changes, nothing is polled.
Singleton {
    id: root

    property string kind: "" // "vol" | "br" | "charge" | "unplug"
    property string extra: "" // shown after the percentage: "1h 10m to full"
    property real value: 0
    property bool muted: false
    property bool shown: false
    property bool ready: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool sinkMuted: sink?.audio?.muted ?? false

    function show(k: string, v: real, m: bool, x: string): void {
        // the volume/brightness popover already shows the level
        if (!ready || Panels.current === "volume" || Panels.current === "brightness")
            return;
        kind = k;
        value = v;
        muted = m;
        extra = x || "";
        shown = true;
        hide.restart();
    }

    onVolumeChanged: show("vol", volume, sinkMuted, "")
    onSinkMutedChanged: show("vol", volume, sinkMuted, "")

    Connections {
        target: Brightness

        function onRawChanged(): void {
            root.show("br", Brightness.value, false, "");
        }
    }

    // a new default output (headphones plugged in) isn't a volume change
    // ---- battery
    readonly property var battery: UPower.displayDevice
    readonly property bool plugged: battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge
    property var warned: [] // low-battery steps already notified since the last charge

    onPluggedChanged: {
        if (!battery.isLaptopBattery)
            return;
        if (plugged) {
            warned = [];
            show("charge", battery.percentage, false, battery.timeToFull > 0 ? `${Fmt.uptime(battery.timeToFull)} to full` : "");
        } else {
            show("unplug", battery.percentage, false, battery.timeToEmpty > 0 ? `${Fmt.uptime(battery.timeToEmpty)} left` : "");
        }
    }

    Connections {
        target: root.battery

        function onPercentageChanged(): void {
            const b = root.battery;
            if (!b.isLaptopBattery || root.plugged)
                return;
            const pct = Math.round(b.percentage * 100);
            for (const step of [5, 10, 20]) {
                if (pct <= step && !root.warned.includes(step)) {
                    root.warned = [...root.warned, step];
                    Quickshell.execDetached(["notify-send", "-a", "battery", "-u", step <= 10 ? "critical" : "normal", `battery ${pct}%`, step <= 10 ? "plug in the charger soon" : "getting low"]);
                    break;
                }
            }
        }
    }

    onSinkChanged: {
        ready = false;
        settle.restart();
    }

    PwObjectTracker {
        objects: [root.sink].filter(n => n)
    }

    Timer {
        id: settle

        running: true
        interval: 2000
        onTriggered: root.ready = true
    }

    Timer {
        id: hide

        interval: 1500
        onTriggered: root.shown = false
    }
}
