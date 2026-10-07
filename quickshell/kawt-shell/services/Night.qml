pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Night light: warmer screen colors through hyprsunset, which kawt runs while it's on
// (Settings.nightLight, Settings.nightTemp in kelvin). Stopping hyprsunset puts the normal
// colors back, so closing kawt never leaves the screen orange.
// Don't run your own hyprsunset next to it: two of them fight over the colors.
//   qs -c kawt-shell ipc call kawt night
Singleton {
    id: root

    property bool available: false
    readonly property bool on: available && Settings.nightLight
    readonly property int temp: Math.max(1000, Math.min(6500, Settings.nightTemp))

    function warmer(): void {
        Settings.nightTemp = Math.max(2500, temp - 500);
    }

    function cooler(): void {
        Settings.nightTemp = Math.min(6000, temp + 500);
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() !== ""
        }
    }

    Process {
        id: sunset

        running: root.on
        command: ["hyprsunset", "-t", String(root.temp)]
    }

    // a new temperature: start hyprsunset again with it
    onTempChanged: if (sunset.running) {
        sunset.running = false;
        restart.restart();
    }

    Timer {
        id: restart

        interval: 200
        onTriggered: sunset.running = Qt.binding(() => root.on)
    }
}
