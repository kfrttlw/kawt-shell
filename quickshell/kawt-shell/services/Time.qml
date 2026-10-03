pragma Singleton
import QtQuick
import Quickshell
import qs.config

// The shell's clock. It can run shifted from the system clock (Settings.timeOffset, minutes):
// only kawt sees that time (bar, calendar, todo reminders, lock screen), the system clock and
// every other program stay as they are.
Singleton {
    id: root

    readonly property int offset: Settings.timeOffset
    property date now: new Date(Date.now() + offset * 60000)

    // bar clock text, from the clock settings
    readonly property string barText: {
        const time = Settings.clock24 ? (Settings.clockSeconds ? "hh:mm:ss" : "hh:mm") : (Settings.clockSeconds ? "h:mm:ss AP" : "h:mm AP");
        return Qt.formatDateTime(now, (Settings.clockDate ? "ddd dd.MM " : "") + time).toLowerCase();
    }

    // "+3h 30m" / "-45m" / "" for the cfg tab
    readonly property string offsetText: {
        if (offset === 0)
            return "";
        const a = Math.abs(offset);
        return (offset > 0 ? "+" : "-") + (a >= 60 ? `${Math.floor(a / 60)}h ` : "") + (a % 60 ? `${a % 60}m` : "");
    }

    // shell time in ms; use this instead of Date.now() for anything the user sees
    function ms(): real {
        return Date.now() + offset * 60000;
    }

    // "14:30" -> the shell clock shows 14:30 now  ·  "+3h", "-30m", "+1h30m" -> shift by that
    // returns an error text, or "" if it worked
    function set(text: string): string {
        text = text.trim();
        let m;
        if ((m = text.match(/^(\d{1,2}):(\d{2})$/))) {
            const real = new Date();
            const target = new Date(real.getFullYear(), real.getMonth(), real.getDate(), parseInt(m[1]), parseInt(m[2]));
            let diff = Math.round((target.getTime() - real.getTime()) / 60000);
            // pick the nearest: 00:10 typed at 23:50 means 20 minutes ahead, not 23h40m back
            if (diff > 720)
                diff -= 1440;
            else if (diff < -720)
                diff += 1440;
            Settings.timeOffset = diff;
        } else if ((m = text.match(/^([+-])\s*(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?$/i)) && (m[2] || m[3])) {
            const mins = (parseInt(m[2] || "0") * 60 + parseInt(m[3] || "0"));
            Settings.timeOffset += m[1] === "-" ? -mins : mins;
        } else {
            return "format: 14:30, +3h, -30m, +1h30m";
        }
        tick();
        return "";
    }

    function reset(): void {
        Settings.timeOffset = 0;
        tick();
    }

    function tick(): void {
        now = new Date(ms());
    }

    onOffsetChanged: tick()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.tick()
    }
}
