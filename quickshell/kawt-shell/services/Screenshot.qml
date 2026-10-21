pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.utils

// Screenshots through scripts/screenshot.sh (grim + slurp).
// Settings.screenshotAsk (the default): the shot waits in ~/.cache/kawt/shots and a preview in
// the bottom-right corner offers [copy] [save] [open] (modules/shot/ShotPreview.qml). Left
// alone, the preview goes and the shot isn't kept (the cache is cleaned after an hour).
// Otherwise it's saved to Settings.screenshotDir at once, copied, and announced.
//   qs -c kawt-shell ipc call kawt screenshot region|window|screen
Singleton {
    id: root

    readonly property string cacheDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/kawt/shots`
    readonly property int timeout: 10000 // the preview goes after this long without the pointer on it
    property string pending: ""
    property bool asking: false // Settings.screenshotAsk, as it was when the shot was taken
    property string shot: "" // the file waiting in the preview; "" = no preview
    property string mode: "" // the shot's mode, for the preview's title
    property string screen: "" // the preview shows on the screen that had the focus
    property bool copied: false

    function take(m: string): void {
        if (job.running)
            return; // the area selection is still open
        // close kawt's panels first so they aren't in the picture; a waiting shot goes too
        Panels.close();
        dismiss();
        pending = m;
        asking = Settings.screenshotAsk;
        screen = Panels.focusedScreen;
        delay.restart();
    }

    function copy(): void {
        if (!shot)
            return;
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", shot]);
        copied = true;
    }

    // into Settings.screenshotDir, announced like an unasked shot; the preview goes
    function save(): void {
        if (!shot)
            return;
        Quickshell.execDetached(["sh", "-c", 'f="$2/${1##*/}"; if mkdir -p "$2" && mv -- "$1" "$f"; then notify-send -a screenshot -i "$f" "screenshot saved" "${f#"$HOME"/}$3"; else notify-send -a screenshot -u critical "screenshot not saved" "could not write to $2"; fi', "sh", shot, Settings.expand(Settings.screenshotDir), copied ? "  ·  copied to clipboard" : ""]);
        shot = "";
    }

    // in the image viewer; the preview stays, to copy or save it still
    function open(): void {
        if (shot)
            Quickshell.execDetached(["xdg-open", shot]);
    }

    function dismiss(): void {
        shot = "";
        copied = false;
    }

    Timer {
        id: delay

        interval: 200
        onTriggered: {
            // asked shots nobody saved: an hour later they go
            if (root.asking)
                Quickshell.execDetached(["sh", "-c", 'find "$1" -maxdepth 1 -name "*.png" -mmin +60 -delete 2> /dev/null', "sh", root.cacheDir]);
            job.command = ["sh", `${Quickshell.shellDir}/scripts/screenshot.sh`, root.pending, root.asking ? root.cacheDir : Settings.expand(Settings.screenshotDir), Colors.palette.accent + "ff", Colors.palette.bg + "88", root.asking ? "quiet" : ""];
            job.running = true;
        }
    }

    // the script prints the file's path; a cancelled selection prints nothing and exits 1
    Job {
        id: job

        onDone: (code, out) => {
            const file = out.trim().split("\n").pop();
            if (code !== 0 || !file || !root.asking)
                return;
            root.mode = root.pending;
            root.copied = false;
            root.shot = file;
        }
    }
}
