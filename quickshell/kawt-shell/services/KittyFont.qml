pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.utils

// kitty's font (settings -> look -> terminal). scripts/kitty-font.sh writes it into
// ~/.config/kitty/kawt-font.conf, which kawt's kitty.conf reads after its own, and every open kitty
// takes it at once. That file is the one place the choice lives (./install.sh asks it there too):
// its first line, "# kawt-font: vga 32", is read back here. No file: kitty.conf's, plex at 14 pt.
// A pixel font is sharp only when each of its pixels is one of the screen's: its sizes are in
// screen pixels, the points worked out from the screen's scale; when the scale changes (another
// monitor, another scale), the file is written again for it. A font just picked comes at "auto":
// the size nearest 19 of hyprland's pixels (plex at 14 pt is 18.7), at the scale there is then
// (the installer's pick too).
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kitty`
    // grid: the font's pixel, its sizes are whole times it; sizes: its own (terminus has a
    // bitmap for each), or the points offered for a smooth one (scripts/kitty-font.sh: the same)
    readonly property var fonts: [
        { id: "term", name: "kawt Term", unit: "px", sizes: [12, 14, 16, 18, 20, 22, 24, 28, 32] },
        { id: "plex", name: "IBM Plex Mono", unit: "pt", sizes: [11, 12, 13, 14, 15, 16] },
        { id: "vga", name: "kawt VGA", unit: "px", grid: 16 },
        { id: "bigblue", name: "Big Blue Terminal", unit: "px", grid: 12 },
        { id: "3270", name: "IBM 3270", unit: "pt", sizes: [12, 13, 14, 15, 16, 18] }
    ]
    // the scale of the biggest monitor: where the terminals mostly are. 0 until hyprland says
    readonly property real scale: {
        let best = null;
        for (const m of Hyprland.monitors.values)
            if (!best || m.width * m.height > best.width * best.height)
                best = m;
        return best?.scale ?? 0;
    }
    readonly property real shownScale: scale || 1
    property string font: "" // what the file says; "" none picked there
    property real size: 0
    property bool auto: false // the size follows the scale (picked with the font, not by hand)
    readonly property string shown: font || "plex"
    readonly property real shownSize: font ? size : 14
    property bool kawtKitty: false // kitty.conf is kawt's: it reads kawt-font.conf
    property string missing: "" // the package of the font asked for last, when it isn't installed
    property var asked: null // [font, size] waiting while the script still runs

    function fontOf(id: string): var {
        return fonts.find(f => f.id === id) ?? fonts[0];
    }

    // the sizes to offer, at this screen's scale: a pixel font's only where its pixels are the
    // screen's, from about 10 to 44 of hyprland's (layout) pixels
    function sizesOf(id: string): var {
        const f = fontOf(id);
        if (f.unit === "pt")
            return f.sizes;
        const all = f.sizes ?? [1, 2, 3, 4, 5].map(k => k * f.grid);
        const fit = all.filter(px => px / shownScale >= 10 && px / shownScale <= 44);
        return fit.length ? fit : [all[0]];
    }

    // size: a number, or "auto" (the script picks it for the scale)
    function pick(id: string, size: var): void {
        if (job.running) {
            asked = [id, size];
            return;
        }
        job.command = ["sh", `${Quickshell.shellDir}/scripts/kitty-font.sh`, id, String(size), String(shownScale)];
        job.running = true;
    }

    // the scale changed, or kawt just started: the picked one written again for it (the script
    // leaves the file, and kitty, alone when nothing would change)
    Timer {
        id: again

        interval: 1500
        onTriggered: if (root.font && root.kawtKitty && root.scale > 0)
            root.pick(root.font, root.auto ? "auto" : root.size)
    }

    onScaleChanged: again.restart()
    onKawtKittyChanged: again.restart()

    FileView {
        path: `${root.dir}/kawt-font.conf`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            const m = t.match(/^# kawt-font: (\S+) ([0-9.]+)( auto)?/m);
            // the file of an older kawt (Departure Mono, 22 px: blurred by kitty's hinting): the
            // pixel font now, sharp at the size the screen takes. The package's Terminus, picked
            // before kawt had its own: kawt's (the script takes "terminus" for it too)
            const old = !m && t.startsWith("# kawt: its pixel font in kitty");
            root.font = m ? (m[1] === "terminus" ? "term" : m[1]) : old ? "term" : "";
            root.size = m ? Number(m[2]) : 0;
            root.auto = old || !!(m && m[3]);
            if (old)
                again.restart();
        }
        onLoadFailed: {
            root.font = "";
            root.size = 0;
        }
    }

    FileView {
        path: `${root.dir}/kitty.conf`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.kawtKitty = /^globinclude kawt-\*\.conf/m.test(text())
        onLoadFailed: root.kawtKitty = false
    }

    Job {
        id: job

        onDone: (code, out) => {
            root.missing = code === 4 ? (out.match(/^missing (\S+)/m) ?? [])[1] ?? "" : "";
            if (root.asked) {
                const a = root.asked;
                root.asked = null;
                root.pick(a[0], a[1]);
            }
        }
    }
}
