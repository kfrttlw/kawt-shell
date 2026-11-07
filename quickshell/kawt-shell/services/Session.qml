pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// logind: the screen locks before the machine sleeps, however it was put to sleep (the lid,
// `systemctl suspend`, a power button), and on `loginctl lock-session` (what hypridle and
// other tools use to ask for a lock).
//
// How it holds the sleep off: while awake, kawt keeps a "delay" sleep inhibitor (systemd-inhibit).
// logind then announces the sleep (PrepareForSleep) and waits for us, at most InhibitDelayMaxSec
// (5 s by default): kawt locks, and lets go of the inhibitor only once the lock is on every
// screen (Panels.lockSecure). After waking up it takes a new one.
// Needs gdbus (glib2) and systemd-inhibit; without them `available` stays false and nothing
// here runs. Settings.lockOnSleep turns it off (if hyprlock or another locker does this).
Singleton {
    id: root

    property bool available: false
    readonly property bool enabled: available && Settings.lockOnSleep
    property bool sleeping: false // between PrepareForSleep(true) and the wake-up
    property string sessionPath: "" // our session's logind object, to ignore lock requests for other users

    Process {
        running: true
        command: ["sh", "-c", "command -v gdbus >/dev/null && command -v systemd-inhibit >/dev/null && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() === "yes"
        }
    }

    // "(objectpath '/org/freedesktop/login1/session/_32',)"
    Process {
        running: root.available
        command: ["sh", "-c", 'gdbus call --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 --method org.freedesktop.login1.Manager.GetSession "${XDG_SESSION_ID:-auto}"']
        stdout: StdioCollector {
            onStreamFinished: root.sessionPath = (text.match(/'([^']+)'/) ?? [])[1] ?? ""
        }
    }

    // held while awake; let go (the process ends) once the lock is on, so logind can go on.
    // `cat` on an open stdin waits forever, and exits as soon as kawt closes it: unlike
    // `sleep infinity`, nothing is left running when the inhibitor is stopped
    Process {
        running: root.enabled && !(root.sleeping && Panels.lockSecure)
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=kawt", "--why=lock the screen first", "cat"]
    }

    // gdbus prints one line per signal:
    //   /org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)
    //   /org/freedesktop/login1/session/_32: org.freedesktop.login1.Session.Lock ()
    Process {
        id: monitor

        running: root.enabled
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes(".Manager.PrepareForSleep (")) {
                    root.sleeping = line.includes("(true");
                    if (root.sleeping && !Panels.locked)
                        Panels.lock(false);
                } else if (line.includes(".Session.Lock ()")) {
                    const path = line.slice(0, line.indexOf(":"));
                    if (!root.sessionPath || path === root.sessionPath)
                        Panels.lock(false);
                }
            }
        }
        // restarted if it ever dies (the system bus restarting)
        onExited: if (root.enabled)
            restart.start()
    }

    Timer {
        id: restart

        interval: 5000
        onTriggered: if (root.enabled)
            monitor.running = true
    }
}
