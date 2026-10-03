pragma Singleton
import QtQuick

// Small text-formatting helpers for the terminal look
QtObject {
    readonly property string sparkChars: "▁▂▃▄▅▆▇█"

    // [#######-------] style meter
    function bar(frac: real, width: int): string {
        const f = Math.max(0, Math.min(1, frac || 0));
        const n = Math.round(f * width);
        return "#".repeat(n) + "-".repeat(width - n);
    }

    // ▁▂▅▇ sparkline, scaled to the max of the series
    function spark(values: var): string {
        const max = Math.max(1, ...values);
        return values.map(v => v <= 0 ? " " : sparkChars[Math.min(7, Math.floor(v / max * 7.999))]).join("");
    }

    // bytes/s -> "1.2M", padded to a fixed width so the bar doesn't jitter
    function rate(bytes: real): string {
        const units = ["B", "K", "M", "G"];
        let v = bytes, i = 0;
        while (v >= 1000 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        const s = (v < 10 && i > 0 ? v.toFixed(1) : Math.round(v).toString()) + units[i];
        return s.padStart(5, " ");
    }

    function uptime(seconds: real): string {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor(seconds % 86400 / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        return (d > 0 ? `${d}d ` : "") + (d > 0 || h > 0 ? `${h}h ` : "") + `${m}m`;
    }

    function mmss(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds || 0));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }
}
