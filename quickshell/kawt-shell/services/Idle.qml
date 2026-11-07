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
//
// Around the lock (profile -> cfg -> lock):
//   dim         Settings.dimBeforeLock: 30 s before the idle lock the backlight goes down to a
//               third; a key or the mouse brings it back (laptops: what brightnessctl can set)
//   screen off  Settings.screenOff minutes after the lock (0 = never) the picture goes off
//               (scripts/screen.sh, dpms). Only the picture: wifi, downloads, music and the
//               rest keep running. A key or the mouse brings it back. Caffeine holds it off
Singleton {
    id: root

    property bool caffeine: false
    property bool screenOff: false // the picture is off now (Panels / SysInfo pause what's behind it)

    readonly property string script: `${Quickshell.shellDir}/scripts/screen.sh`

    function setScreen(on: bool): void {
        if (screenOff === !on)
            return;
        screenOff = !on;
        Quickshell.execDetached(["sh", script, on ? "on" : "off"]);
    }

    IdleMonitor {
        enabled: Settings.idleLock > 0 && !root.caffeine
        timeout: Settings.idleLock * 60 // seconds
        respectInhibitors: true
        onIsIdleChanged: if (isIdle && !Panels.locked)
            Panels.lock(false)
    }

    // ---- dim before the idle lock
    property bool dimmed: false
    property real dimFrom: 0 // the brightness before
    property real dimTo: 0 // what it was dimmed to: if someone changed it since, it stays

    IdleMonitor {
        enabled: Settings.dimBeforeLock && Settings.idleLock > 0 && !root.caffeine && Brightness.available
        timeout: Math.max(30, Settings.idleLock * 60 - 30)
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle && !Panels.locked && !root.dimmed) {
                root.dimFrom = Brightness.value;
                root.dimTo = Math.max(0.02, Brightness.value / 3);
                if (root.dimTo < root.dimFrom) {
                    root.dimmed = true;
                    Brightness.set(root.dimTo);
                }
            } else if (!isIdle && root.dimmed) {
                // back at the machine (in front of the lock screen or not): as it was
                root.dimmed = false;
                if (Math.abs(Brightness.value - root.dimTo) < 0.02)
                    Brightness.set(root.dimFrom);
            }
        }
    }

    // ---- the picture off, a while after the lock. Counted from the lock (the monitor starts
    // with it); inhibitors don't count here: nobody watches a video behind the lock screen
    IdleMonitor {
        enabled: Settings.screenOff > 0 && Panels.lockSecure && !root.caffeine
        timeout: Settings.screenOff * 60
        respectInhibitors: false
        onIsIdleChanged: root.setScreen(!isIdle)
    }

    // unlocked (or caffeine on) while it's off: the picture back, whatever happened
    Connections {
        target: Panels

        function onLockedChanged(): void {
            if (!Panels.locked)
                root.setScreen(true);
        }
    }

    onCaffeineChanged: if (caffeine)
        setScreen(true)

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
