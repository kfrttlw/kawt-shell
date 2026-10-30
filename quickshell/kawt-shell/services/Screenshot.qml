pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

// Screenshots through scripts/screenshot.sh (grim + slurp).
// Settings.screenshotAsk (the default): the shot waits in ~/.cache/kawt/shots, already on the
// clipboard, and a preview in the bottom-right corner offers [copy] [save] [open]
// (modules/shot/ShotPreview.qml). Left alone, or followed by the next shot, it's saved; only
// [x] throws it away (the cache is cleaned after an hour).
// Otherwise it's saved to Settings.screenshotDir at once, copied, and announced.
//   qs -c kawt-shell ipc call kawt screenshot region|window|screen
// With the tools installed (each optional, its button only shows with it):
//   hyprpicker   the screen stands still while an area is picked (Settings.screenshotFreeze)
//   satty        [edit]: arrows, boxes, text, blur, in the shot itself (or swappy)
//   tesseract    [text]: the text in the shot, onto the clipboard (the languages it has)
Singleton {
    id: root

    // ---- the optional tools, looked for once
    property bool canFreeze: false
    property string editor: "" // "satty" | "swappy" | ""
    property string ocrLangs: "" // "eng+rus": what tesseract has of the useful ones; "" = no [text]
    property bool editing: editJob.running // the preview waits meanwhile
    property bool reading: textJob.running
    property string textStatus: "" // "text copied", "no text found"
    property int version: 0 // goes up when the shot's file changed (edited): the preview loads it again

    Process {
        running: true
        command: ["sh", "-c", 'command -v hyprpicker; command -v satty || command -v swappy; command -v tesseract > /dev/null && tesseract --list-langs 2> /dev/null | tail -n +2 | tr "\\n" " "']
        stdout: StdioCollector {
            onStreamFinished: {
                root.canFreeze = text.includes("/hyprpicker");
                root.editor = text.includes("/satty") ? "satty" : text.includes("/swappy") ? "swappy" : "";
                // english, plus russian / ukrainian / the rest of the useful ones it has, in that order
                const have = (text.split("\n").pop() ?? "").trim().split(/\s+/);
                root.ocrLangs = ["eng", "rus", "ukr", "deu", "fra", "spa", "pol"].filter(l => have.includes(l)).join("+");
            }
        }
    }

    // [edit]: the editor saves over the waiting shot; the preview shows the result
    function edit(): void {
        if (!shot || !editor || editJob.running)
            return;
        editJob.command = editor === "satty" ? ["satty", "--filename", shot, "--output-filename", shot, "--early-exit", "--copy-command", "wl-copy"] : ["swappy", "-f", shot, "-o", shot];
        editJob.running = true;
    }

    Process {
        id: editJob

        onExited: {
            root.version++;
            root.copied = false; // what's on the clipboard now may be the old picture
        }
    }

    // [text]: what tesseract reads in the shot, onto the clipboard
    function readText(): void {
        if (!shot || !ocrLangs || textJob.running)
            return;
        textStatus = "reading...";
        textJob.command = ["tesseract", shot, "-", "-l", ocrLangs];
        textJob.running = true;
    }

    Job {
        id: textJob

        onDone: (code, out) => {
            const t = out.replace(/\f/g, "").trim();
            if (code !== 0 || !t) {
                root.textStatus = code !== 0 ? "tesseract failed" : "no text found";
                return;
            }
            // through wl-copy, on stdin: the preview never has the keyboard, and wayland only
            // lets a window with it set the clipboard (Quickshell.clipboardText would do nothing)
            copyText.input = t;
            copyText.stdinEnabled = true;
            copyText.running = true;
            const lines = t.split("\n").length;
            root.textStatus = `text copied (${lines} line${lines === 1 ? "" : "s"})`;
        }
    }

    Process {
        id: copyText

        property string input: ""

        command: ["wl-copy"]
        onStarted: {
            write(input);
            input = "";
            stdinEnabled = false;
        }
    }

    readonly property string cacheDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/kawt/shots`
    readonly property int timeout: 10000 // the preview goes after this long without the pointer on it
    property string pending: ""
    property bool asking: false // Settings.screenshotAsk, as it was when the shot was taken
    property string shot: "" // the file waiting in the preview; "" = no preview
    property string mode: "" // the shot's mode, for the preview's title
    property string screen: "" // the preview shows on the screen that had the focus
    property bool copied: false

    // a shot was taken (the companion goes "click!")
    signal taken

    function take(m: string): void {
        // one still running (an area being picked, or one stuck under the frozen screen): a new
        // press starts over instead of being ignored, so the key never just does nothing
        if (job.running)
            job.running = false;
        // close kawt's panels first so they aren't in the picture. A shot still waiting is saved,
        // like one left alone: two in a row used to lose the first
        Panels.close();
        if (shot)
            save();
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

    // into Settings.screenshotDir, announced like an unasked shot; the preview goes. A file of
    // the same name already there stays: this one gets -2 (-3...)
    function save(): void {
        if (!shot)
            return;
        Quickshell.execDetached(["sh", "-c", 'b=${1##*/}; f="$2/$b"; n=2; while [ -e "$f" ]; do f="$2/${b%.png}-$n.png"; n=$((n + 1)); done; if mkdir -p "$2" && mv -- "$1" "$f"; then notify-send -a screenshot -i "$f" "screenshot saved" "${f#"$HOME"/}$3"; else notify-send -a screenshot -u critical "screenshot not saved" "could not write to $2"; fi', "sh", shot, Settings.expand(Settings.screenshotDir), copied ? "  ·  copied to clipboard" : ""]);
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
        textStatus = "";
    }

    Timer {
        id: delay

        interval: 200
        onTriggered: {
            // asked shots nobody saved: an hour later they go
            if (root.asking)
                Quickshell.execDetached(["sh", "-c", 'find "$1" -maxdepth 1 -name "*.png" -mmin +60 -delete 2> /dev/null', "sh", root.cacheDir]);
            job.command = ["env", `KAWT_FREEZE=${Settings.screenshotFreeze && root.canFreeze ? 1 : 0}`, "sh", `${Quickshell.shellDir}/scripts/screenshot.sh`, root.pending, root.asking ? root.cacheDir : Settings.expand(Settings.screenshotDir), Colors.palette.accent.slice(0, 7) + "ff", Colors.palette.bg.slice(0, 7) + "88", root.asking ? "quiet" : ""];
            job.running = true;
        }
    }

    // the script prints the file's path; a cancelled selection prints nothing and exits 1
    Job {
        id: job

        onDone: (code, out) => {
            const file = out.trim().split("\n").pop();
            // 1: esc in the selection, or stopped for a new press: nothing to say. 3 and 4 say why
            if (code !== 0 || !file) {
                if (code === 3 || code === 4)
                    Quickshell.execDetached(["notify-send", "-a", "screenshot", "-u", "critical", "screenshot not taken", code === 3 ? `${file} (sudo pacman -S grim slurp wl-clipboard)` : file]);
                return;
            }
            root.taken();
            if (!root.asking)
                return;
            root.mode = root.pending;
            root.shot = file;
            // on the clipboard at once: pasting works right away, whatever the preview is asked
            root.copy();
        }
    }
}
