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

    // a time of day typed by the user -> { h, m } (24h), or null
    //   "14:30"  "2:30pm"  "2:30 PM"  "2pm"  "12am" (= 00:00)  "12pm" (= 12:00)
    // a bare number ("3") is not a time, so "3 apples" stays plain text
    function parseClock(text: string): var {
        const m = text.trim().match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?$/i);
        if (!m || (m[2] === undefined && !m[3]))
            return null;
        let h = parseInt(m[1]);
        const min = m[2] === undefined ? 0 : parseInt(m[2]);
        if (m[3]) {
            if (h < 1 || h > 12)
                return null;
            h = h % 12 + (m[3].toLowerCase().startsWith("p") ? 12 : 0);
        }
        return h < 24 && min < 60 ? { h, m: min } : null;
    }

    // a time of day shown the way the clock setting says: "14:30" or "2:30 pm"
    function fmt(d: date): string {
        return Settings.clock24 ? Qt.formatTime(d, "hh:mm") : Qt.formatTime(d, "h:mm AP").toLowerCase();
    }

    // shell time in ms; use this instead of Date.now() for anything the user sees
    function ms(): real {
        return Date.now() + offset * 60000;
    }

    // "14:30" / "2:30pm" -> the shell clock shows that now  ·  "+3h", "-30m", "+1h30m" -> shift by that
    // returns an error text, or "" if it worked
    function set(text: string): string {
        text = text.trim();
        let m;
        const clock = parseClock(text);
        if (clock) {
            const real = new Date();
            const target = new Date(real.getFullYear(), real.getMonth(), real.getDate(), clock.h, clock.m);
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
            return "format: 14:30, 2:30pm, +3h, -30m, +1h30m";
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
