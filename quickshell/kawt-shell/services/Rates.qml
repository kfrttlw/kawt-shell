pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Once, on the first start in hyprland: does a monitor run slower than it can? From a console
// the installer can't see refresh rates (the kernel lists the sizes only), so it writes the best
// size and leaves the rate to here. "DP-1 runs at 60 Hz, it can do 165": Set it opens a terminal
// with ./install.sh --monitors (pick, try it, keep it or have it back); Leave it, and it isn't
// asked again (Settings.ratesAsked).
Singleton {
    id: root

    readonly property bool wanted: !Settings.ratesAsked
    property var slow: [] // [{ name, now, best }] Hz

    Timer {
        running: Settings.loaded && root.wanted
        interval: 12000 // after the start's own work, and the first-start tour
        onTriggered: {
            Hyprland.refreshMonitors();
            look.restart();
        }
    }

    Timer {
        id: look

        interval: 1500
        onTriggered: root.check()
    }

    // the highest rate at the size each one runs at now, against its rate now
    function check(): void {
        const out = [];
        for (const m of Hyprland.monitors.values) {
            const o = m.lastIpcObject ?? {};
            const size = `${o.width}x${o.height}`;
            const now = Number(o.refreshRate ?? 0);
            const best = Math.max(0, ...(o.availableModes ?? []).filter(s => s.startsWith(size + "@")).map(s => parseFloat(s.split("@")[1])));
            if (now > 0 && best - now > 1.5)
                out.push({ name: m.name, now: Math.round(now), best: Math.round(best) });
        }
        Settings.ratesAsked = true;
        slow = out;
        if (out.length === 0)
            return;
        const lines = out.map(s => Strings.t("ratesLine").arg(s.name).arg(s.now).arg(s.best));
        ask.command = ["notify-send", "-a", "kawt", "-i", "video-display", "-A", `set=${Strings.t("ratesSet")}`, "-A", `no=${Strings.t("ratesLeave")}`, Strings.t("ratesTitle"), lines.join("\n")];
        ask.running = true;
    }

    // the answer: the action's name on stdout (notify-send waits for it)
    Process {
        id: ask

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "set" && Update.repo)
                    Apps.runInTerminal(`'${Update.repo.replace(/'/g, "'\\''")}/install.sh' --monitors`);
            }
        }
    }
}
