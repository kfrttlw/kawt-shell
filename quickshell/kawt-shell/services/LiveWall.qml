pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.config

// Live wallpapers: a video (or a moving gif) in the wallpaper folder, picked like a picture
// (super + w). Played by mpvpaper (mpv as the wallpaper), as little as can be:
//   - its first frame is always the wallpaper under it (services/Wallpapers.qml: in the theme's
//     tones or as it is, like a picture), and that's all there is while it doesn't play
//   - it plays with any windows over it, tiled or floating, and stops only while every screen
//     has one maximized or fullscreen (or a scratchpad) over it: then the player isn't paused
//     but closed (no memory at all), and goes on where it was when the desktop shows again
//   - not on battery (Settings.liveOnBattery), nor behind the lock, the screen off, or with less
//     than 1 GB of memory left
//   - what plays is a light copy, made once (scripts/live.sh): cut to the screen, 24 frames a
//     second, silent, two minutes at most; in the theme's tones at half the screen's size, the
//     dots doubled by the player (made again on a theme switch, a few seconds at low priority)
// mpv runs with none of your own mpv.conf or scripts (MPV_HOME: an empty folder of kawt's).
Singleton {
    id: root

    readonly property var kinds: ["mp4", "webm", "mkv", "mov", "m4v", "avi", "gif"]
    readonly property string script: `${Quickshell.shellDir}/scripts/live.sh`
    readonly property string dir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/kawt/live`

    function isLive(path: string): bool {
        const m = /\.([a-z0-9]+)$/i.exec(path ?? "");
        return !!m && kinds.includes(m[1].toLowerCase());
    }

    property bool found: false // mpvpaper is there, looked for at the start
    readonly property string file: Settings.wallpaper
    readonly property bool live: isLive(file)
    readonly property bool dots: Settings.wallDither
    // the copy: the file, how it's shown, the screen, and in the theme's tones its colors (as
    // the dithered pictures have them)
    readonly property string mode: dots ? "tones" : "plain"
    readonly property var args: {
        const s = Wallpapers.ditherSize, t = Wallpapers.tones;
        return dots ? [s.width, s.height, String(t.lo), String(t.hi), String(Colors.accent), String(t.gamma), ...Wallpapers.keyOf(file)].map(String) : [s.width * 2, s.height * 2].map(String);
    }
    readonly property string wanted: live && found ? `${dir}/${Qt.md5([file, mode, ...args].join("|"))}.mkv` : ""
    property string ready: "" // the copy that's made
    property real length: 0 // its seconds
    property string failed: "" // ffmpeg couldn't make this one: the still stays

    // a desktop is seen: some screen has no window maximized or fullscreen on the workspace it
    // shows (nor a scratchpad over it)
    readonly property bool seen: Hyprland.monitors.values.some(m => !covered(m))

    function covered(m: var): bool {
        return !!m.lastIpcObject?.specialWorkspace?.name || (m.activeWorkspace?.toplevels?.values ?? []).some(w => !!w.lastIpcObject?.fullscreen);
    }

    // hyprland tells which windows are fullscreen only when asked: asked after each change that
    // may fill or free a screen
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (root.live && ["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspacev2", "activespecial"].includes(event.name))
                ask.restart();
        }
    }

    Timer {
        id: ask

        interval: 250
        onTriggered: Hyprland.refreshToplevels()
    }

    // and once at the start, or when a live one is picked
    onLiveChanged: if (live)
        Hyprland.refreshToplevels()
    Component.onCompleted: if (live)
        Hyprland.refreshToplevels()
    property bool lowMemory: false
    readonly property bool batteryStill: UPower.onBattery && !Settings.liveOnBattery
    readonly property bool play: wanted !== "" && ready === wanted && seen && !Panels.locked && !Idle.screenOff && !batteryStill && !lowMemory
    readonly property bool playing: player.running
    // why it's still now, for the style window: "" (it plays, or it's no live one)
    readonly property string still: !live || player.running ? "" : !found ? "missing" : failed === wanted ? "failed" : ready !== wanted ? "making" : lowMemory ? "memory" : batteryStill ? "battery" : !seen ? "covered" : ""

    // where it got to: the player goes on from there next time
    property real at: 0
    property real since: 0
    property int crashes: 0 // the player quit by itself, right after starting: tried twice, then left

    onFileChanged: {
        at = 0;
        crashes = 0;
    }
    onWantedChanged: {
        stop();
        if (wanted)
            makeSoon.restart();
    }
    onPlayChanged: play ? startSoon.restart() : stop()

    // ---- the copy
    property bool again: false // asked for another while one was made

    function make(): void {
        if (!wanted || ready === wanted)
            return;
        if (maker.running) {
            again = true;
            return;
        }
        maker.command = ["sh", script, mode, file, wanted, ...args];
        maker.running = true;
    }

    // a theme picked through a few at once: only the last one is made
    Timer {
        id: makeSoon

        interval: 800
        onTriggered: root.make()
    }

    Process {
        id: maker

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const out = lines[0] ?? "";
                const made = maker.command[4];
                if (out && out === made) {
                    root.length = Number(lines[1]) || 0;
                    root.ready = out;
                } else {
                    root.failed = made;
                    console.warn(`live wallpaper: couldn't make a copy of ${root.file} (ffmpeg, and the file there?)`);
                }
            }
        }
        onExited: if (root.again) {
            root.again = false;
            Qt.callLater(root.make);
        }
    }

    // ---- the player
    function start(): void {
        if (player.running || !play)
            return;
        const from = length > 0 ? at % length : 0;
        const options = ["no-audio", "loop-file=inf", "hwdec=auto-safe", "panscan=1.0", "osc=no", "input-default-bindings=no", "terminal=no", "cache=no", "demuxer-readahead-secs=1", "demuxer-max-bytes=8MiB", "demuxer-max-back-bytes=0", "vd-lavc-threads=2", "hr-seek=no", ...(dots ? ["scale=nearest"] : []), `start=${from.toFixed(1)}`];
        player.command = ["mpvpaper", "-o", options.join(" "), "*", ready];
        since = Date.now();
        player.running = true;
    }

    function stop(): void {
        startSoon.stop();
        if (!player.running)
            return;
        at += (Date.now() - since) / 1000;
        player.running = false;
    }

    // a window closed and another opened at once: no start for that moment
    Timer {
        id: startSoon

        interval: 700
        onTriggered: root.start()
    }

    Process {
        id: player

        environment: ({
                MPV_HOME: `${root.dir}/mpv`
            })
        onExited: (code, status) => {
            // quit by itself while it should play (stopped by kawt it's not running any more by then)
            if (!root.play)
                return;
            const quick = Date.now() - root.since < 3000;
            root.crashes = quick ? root.crashes + 1 : 0;
            console.warn(`live wallpaper: mpvpaper quit (${code})${root.crashes >= 2 ? ", not started again" : ""}`);
            if (root.crashes < 2)
                startSoon.restart();
        }
    }

    // ---- memory: under 1 GB available it stops, over 1.5 GB it may play again
    Timer {
        interval: 15000
        running: root.live
        repeat: true
        triggeredOnStart: true
        onTriggered: meminfo.reload()
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        preload: false
        onLoaded: {
            const kb = Number((text().match(/^MemAvailable:\s+(\d+)/m) ?? [])[1] ?? 0);
            if (kb > 0 && kb < 1024 * 1024)
                root.lowMemory = true;
            else if (kb > 1536 * 1024)
                root.lowMemory = false;
        }
    }

    // mpvpaper there? And a player left from a kawt that stopped all at once: gone (only kawt's
    // own copies are played from that folder)
    Process {
        running: true
        command: ["sh", "-c", 'pkill -f "kawt/live/[0-9a-f]+\\.mkv"; mkdir -p "$1/mpv"; command -v mpvpaper', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.found = text.trim() !== "" // the copy is made then (onWantedChanged)
        }
    }
}
