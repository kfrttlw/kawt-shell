pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Screenshots through scripts/screenshot.sh (grim + slurp): saved to Settings.screenshotDir,
// copied to the clipboard, announced with a notification.
//   qs -c kawt-shell ipc call kawt screenshot region|window|screen
Singleton {
    id: root

    property string pending: ""

    function take(mode: string): void {
        // close kawt's panels first so they aren't in the picture
        Panels.close();
        pending = mode;
        delay.restart();
    }

    Timer {
        id: delay

        interval: 200
        onTriggered: Quickshell.execDetached(["sh", `${Quickshell.shellDir}/scripts/screenshot.sh`, root.pending, Settings.expand(Settings.screenshotDir), Colors.palette.accent + "ff", Colors.palette.bg + "88"])
    }
}
