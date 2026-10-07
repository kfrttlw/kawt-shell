pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Idle: the screen locks after Settings.idleLock minutes without input (0 = never).
// Apps that ask to keep the screen on (a video, a call) hold it off, and so does caffeine:
// [caf] in the bar keeps the screen on until it's switched off again. Caffeine is not saved
// on purpose: after a restart the machine locks itself again.
//   qs -c kawt-shell ipc call kawt caffeine
Singleton {
    id: root

    property bool caffeine: false

    IdleMonitor {
        enabled: Settings.idleLock > 0 && !root.caffeine
        timeout: Settings.idleLock * 60 // seconds
        respectInhibitors: true
        onIsIdleChanged: if (isIdle && !Panels.locked)
            Panels.lock(false)
    }

    // an inhibitor needs a surface of its own: an empty, click-through one
    IdleInhibitor {
        enabled: root.caffeine
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }
}
