pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// On-screen display for volume and brightness: whatever changes them (media keys, the bar,
// another app), the new level pops up for a moment. Quiet for the first seconds after start,
// so loading the current values doesn't count as a change.
Singleton {
    id: root

    property string kind: "" // "vol" | "br"
    property real value: 0
    property bool muted: false
    property bool shown: false
    property bool ready: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool sinkMuted: sink?.audio?.muted ?? false

    function show(k: string, v: real, m: bool): void {
        // the volume/brightness popover already shows the level
        if (!ready || Panels.current === "volume" || Panels.current === "brightness")
            return;
        kind = k;
        value = v;
        muted = m;
        shown = true;
        hide.restart();
    }

    onVolumeChanged: show("vol", volume, sinkMuted)
    onSinkMutedChanged: show("vol", volume, sinkMuted)

    Connections {
        target: Brightness

        function onRawChanged(): void {
            root.show("br", Brightness.value, false);
        }
    }

    // a new default output (headphones plugged in) isn't a volume change
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
