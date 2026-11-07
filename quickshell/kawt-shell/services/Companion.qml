pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.config
import qs.utils
import "../utils/stripes.js" as Talk

// The companion, stripes: a stain of glitching data in a girl's outline (shaders/stripes.frag,
// drawn by modules/companion/Her.qml). She walks about an empty desktop and falls asleep there
// when nothing happens, peeks out of the corner when something does (the battery, a screenshot,
// a reminder, a new kawt), sits next to the coder and keeps the focus timer with you.
// super + h calls her out of the corner, and lets her go again. Her eyes follow the pointer.
// Nothing ticks for her while she's nowhere on the screen.
//
//   Settings.companion       on / off (off: nothing runs for her)
//   Settings.companionLook   "mood" (she picks: stripes when calm, red when busy, ink at night
//                            and asleep) | "red" | "ink" | "stripes"
//   Settings.companionMode   "walk" (an empty desktop is hers) | "home" (she keeps off it)
//   Settings.companionName   "" = stripes
//   Settings.companionLang   "en" | "ru": what she says
// Her file (when you met, your phrases for her) is ~/.local/state/kawt/companion.json.
//   qs -c kawt-shell ipc call kawt companion pet|call|sleep|wake|focus|walk|home|toggle
Singleton {
    id: root

    readonly property bool enabled: Settings.companion
    readonly property string lang: Settings.companionLang === "ru" ? "ru" : "en"
    readonly property string name: Settings.companionName || "stripes"

    // ------------------------------------------------------------------ her look

    // what's going on, for "mood"
    readonly property bool music: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool recording: Recorder.recording
    // the coder at work (aiMode first: in chat mode the coder service never even loads)
    readonly property bool coding: Settings.aiMode === "coder" && Panels.sidebarOpen && (Coder.running || Coder.thinking)
    readonly property bool busy: music || recording || coding || batteryLow
    readonly property string mood: sleeping || night ? "ink" : busy ? "red" : "stripes"
    readonly property string look: ["red", "ink", "stripes"].includes(Settings.companionLook) ? Settings.companionLook : mood

    // she changes through a glitch: torn into bars, put together as the other one
    onLookChanged: glitch(650)

    function lum(c: color): real {
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    // on paper (a light theme) she's ink and red ink, not light
    readonly property bool paper: lum(Colors.bg) > lum(Colors.fg)
    // her colors for the shader, dark to hot, from the theme: { c: 9 of them (straight alpha,
    // the last repeated), n: how many are hers }. Tuned on thinkpad's black and paper
    readonly property var ramp: rampOf(look, paper)
    readonly property vector4d eyeColor: {
        const c = look === "stripes" ? Colors.accent : paper ? Colors.fg : mixed(Colors.fg, Qt.rgba(1, 1, 1, 1), 0.7);
        return Qt.vector4d(c.r, c.g, c.b, 1);
    }

    function mixed(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    function rampOf(look: string, paper: bool): var {
        const a = Colors.accent, f = Colors.fg, b = Colors.bg, w = Qt.rgba(1, 1, 1, 1);
        const none = Qt.vector4d(0, 0, 0, 0);
        // a color made darker, or a mix of two; with its alpha
        const k = (c, t, al) => Qt.vector4d(c.r * t, c.g * t, c.b * t, al ?? 1);
        const m = (c, d, t, al) => Qt.vector4d(c.r + (d.r - c.r) * t, c.g + (d.g - c.g) * t, c.b + (d.b - c.b) * t, al ?? 1);
        let r;
        if (look === "red")
            r = paper ? [none, k(a, 1, 0.27), k(a, 1, 0.59), k(a, 1, 0.9), k(a, 0.77), k(a, 0.46), k(f, 1)] : [none, k(a, 0.26, 0.43), k(a, 0.49, 0.78), k(a, 0.84, 0.94), k(a, 1), m(a, w, 0.4), m(a, w, 0.87)];
        else if (look === "ink")
            r = paper ? [none, k(f, 1, 0.24), k(f, 1, 0.51), k(f, 1, 0.78), k(f, 1, 0.96), k(f, 0.41), k(a, 1)] : [none, m(b, f, 0.185, 0.43), m(b, f, 0.34, 0.78), m(b, f, 0.535, 0.94), m(b, f, 0.785), k(f, 1), m(f, w, 0.8)];
        // the stripes: the theme's ink, and her hottest spot in the red
        else
            r = paper ? [none, m(b, f, 0.47, 0.43), m(b, f, 0.57, 0.7), m(b, f, 0.78, 0.9), m(b, f, 0.95, 0.98), k(f, 1), k(f, 0.69), k(f, 0.41), k(a, 1)] : [none, m(b, f, 0.34, 0.59), m(b, f, 0.535, 0.82), m(b, f, 0.74, 0.96), m(b, f, 0.925), k(f, 1), m(f, w, 0.35), m(f, w, 0.7), k(a, 1)];
        const n = r.length;
        while (r.length < 9)
            r.push(r[n - 1]);
        return { c: r, n };
    }

    // ------------------------------------------------------------------ her clock

    property int viewers: 0 // Her.qml on the screen right now
    property int deskViews: 0 // the desktop one among them
    readonly property bool shown: enabled && viewers > 0 && !Panels.locked
    readonly property real started: Date.now()
    property real t: 0 // seconds for the shader, wrapped by the hour (the noise keeps its precision)
    property real fit: 0 // a glitch now: 0 .. 1
    property bool blink: false
    property int step: 0 // a beat for walking (modules/companion/Walker.qml)
    property real fitFrom: 0
    property real fitUntil: 0
    property real nextFit: 0
    property real blinkUntil: 0
    property real nextBlink: 0

    // 12 frames a second, twice that in a glitch, half asleep
    Timer {
        running: root.shown
        repeat: true
        interval: root.fit > 0 ? 42 : root.sleeping ? 166 : 83
        onTriggered: root.frame()
    }

    Timer {
        running: root.shown
        repeat: true
        interval: 220
        onTriggered: root.step++
    }

    function frame(): void {
        const n = Date.now();
        t = (n - started) / 1000 % 3600;
        // now and then, awake, a glitch of her own (the first comes as she shows up)
        if (n >= nextFit) {
            nextFit = n + 5000 + Math.random() * 5000;
            if (!sleeping)
                glitch(300 + Math.random() * 400);
        }
        fit = n < fitUntil ? 1 - (n - fitFrom) / (fitUntil - fitFrom) * 0.6 : 0;
        if (n >= nextBlink) {
            blinkUntil = n + 150;
            nextBlink = n + 2500 + Math.random() * 4000;
        }
        blink = n < blinkUntil;
    }

    function glitch(ms: int): void {
        fitFrom = Date.now();
        fitUntil = fitFrom + ms;
    }

    // ------------------------------------------------------------------ the pointer

    // where the pointer is, for her eyes: { x, y } on hyprland's whole layout, or null. Asked a
    // few times a second, only while she's awake on the screen
    property var cursor: null

    Timer {
        running: root.shown && !root.sleeping
        repeat: true
        interval: 350
        onTriggered: if (!pointer.running)
            pointer.running = true
        onRunningChanged: if (!running)
            root.cursor = null
    }

    Process {
        id: pointer

        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/(-?\d+(?:\.\d+)?)\D+(-?\d+(?:\.\d+)?)/);
                const c = m ? { x: Number(m[1]), y: Number(m[2]) } : null;
                if (c?.x !== root.cursor?.x || c?.y !== root.cursor?.y)
                    root.cursor = c;
            }
        }
    }

    // ------------------------------------------------------------------ awake, asleep

    property real now: Date.now() // read once a minute (and at whatever happens)
    property real quietSince: Date.now() // the last time something happened with her
    property bool napping: false
    readonly property bool sleeping: Panels.locked || napping
    readonly property bool night: {
        const h = new Date(now).getHours();
        return h >= 1 && h < 5;
    }

    // something happened with her: she's up for it
    function touch(): void {
        now = Date.now();
        quietSince = now;
        napping = false;
    }

    function wake(): void {
        const was = napping;
        touch();
        if (was)
            say(line("woke", ""), 0);
    }

    function sleep(): void {
        now = Date.now();
        napping = true;
        act = "";
        actTimer.stop();
        say(line("sleep", ""), 2000);
    }

    // the minute: nothing for a while and she dozes off (sooner at night); a yawn once a night
    Timer {
        running: root.enabled && root.loaded
        repeat: true
        interval: 60000
        triggeredOnStart: true
        onTriggered: root.minute()
    }

    function minute(): void {
        now = Date.now();
        if (!napping && now - quietSince > (night ? 5 : 20) * 60000) {
            napping = true;
            act = "";
        }
        const today = Qt.formatDate(new Date(now), "yyyy-MM-dd");
        if (night && life.nightOn !== today && !sleeping && canPeek) {
            life.nightOn = today;
            react("night", "", "yawn", true);
        }
    }

    // ------------------------------------------------------------------ what she does

    // a move for a few seconds: "yawn", "flag", "alarm"... (modules/companion/Her.qml)
    property string act: ""
    // what she does when nothing else is asked of her (the desktop adds walking and dancing)
    readonly property string base: act || (sleeping ? "sleep" : batteryLow ? "alarm" : "")

    // a little jump, wherever she is on the screen
    signal hopped

    Timer {
        id: actTimer

        onTriggered: root.act = ""
    }

    function move(anim: string, ms: int): void {
        if (anim === "hop") {
            hopped();
            return;
        }
        if (anim === "glitch") {
            glitch(700);
            return;
        }
        act = anim;
        actTimer.interval = ms || 3000;
        actTimer.restart();
    }

    // ------------------------------------------------------------------ talking

    property string said: "" // the bubble over her
    property real saidAt: 0

    Timer {
        id: hush

        interval: 4500
        onTriggered: root.said = ""
    }

    function line(kind: string, arg: var): string {
        const t = Talk.talk[lang] ?? Talk.talk.en;
        let list = t[kind] ?? Talk.talk.en[kind] ?? [];
        // your phrases come up as often as all of hers together
        if (kind === "chat" && (own[lang] ?? []).length > 0 && Math.random() < 0.5)
            list = own[lang];
        const s = list.length ? list[Math.floor(Math.random() * list.length)] : "";
        return s.replace("%s", arg ?? "");
    }

    function say(text: string, ms: int): void {
        if (!text)
            return;
        said = text;
        saidAt = Date.now();
        hush.interval = ms || Math.max(3000, Math.min(8000, text.length * 120));
        hush.restart();
    }

    // something happened: a move and a line, wherever she is on the screen. If she's nowhere
    // on it, she peeks out of the corner (not over a fullscreen window, not in dnd, not hidden)
    function react(kind: string, arg: string, anim: string, peek: bool): void {
        if (!enabled)
            return;
        touch();
        if (anim)
            move(anim, 3500);
        say(line(kind, arg), 0);
        if (peek && (viewers === 0 || peeking) && canPeek) {
            peeking = true;
            peekTimer.restart();
        }
    }

    property bool peeking: false
    readonly property bool fullscreen: Hyprland.focusedWorkspace?.hasFullscreen ?? false
    readonly property bool canPeek: !Settings.dnd && !Panels.locked && !fullscreen && life.hiddenUntil < now

    Timer {
        id: peekTimer

        interval: 5000
        onTriggered: root.peeking = false
    }

    // super + h: out of the corner, and she stays there until it's pressed again (or a double
    // click). Already out on the desktop or in her window (start -> stripes), she answers from there
    property bool called: false

    function call(): void {
        if (!enabled || Panels.locked)
            return;
        if (called) {
            called = false;
            return;
        }
        life.hiddenUntil = 0;
        if (deskViews === 0 && Panels.current !== "home") {
            called = true;
            peeking = false;
            peekTimer.stop();
        }
        talkNow();
    }

    // a click on her: what's next, the battery, or a word of hers. Asleep, she wakes up first
    function talkNow(): void {
        if (napping) {
            wake();
            hopped();
            return;
        }
        touch();
        const r = Math.random();
        if (r < 0.15 && battery.isLaptopBattery)
            say(line("battery", `${Math.round(battery.percentage * 100)}%${plugged ? "+" : ""}`), 0);
        else if (r < 0.3 && nextTask())
            say(line("next", nextTask()), 0);
        else if (night && r < 0.6)
            say(line("night", ""), 0);
        else if (r < 0.55 && Settings.companionQuotes)
            wise();
        else
            say(line("chat", ""), 0);
        hopped();
    }

    // a wise word: fortune's (fortune-mod, english only) or one of hers
    function wise(): void {
        if (hasFortune && lang === "en" && Math.random() < 0.6 && !fortune.running) {
            fortune.running = true;
            return;
        }
        say(line("wise", ""), 0);
    }

    property bool hasFortune: false

    Process {
        running: root.enabled
        command: ["sh", "-c", "command -v fortune"]
        stdout: StdioCollector {
            onStreamFinished: root.hasFortune = text.trim() !== ""
        }
    }

    // short ones only: they have to fit her bubble
    Process {
        id: fortune

        command: ["fortune", "-s", "-n", "140"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.replace(/\s+/g, " ").trim();
                root.say(t || root.line("wise", ""), 0);
            }
        }
    }

    function nextTask(): string {
        const t = Todo.today[0];
        return t ? `${t.text} · ${Time.fmt(new Date(t.due))}` : "";
    }

    // off the desktop and out of the corners for an hour (a double click on her): she says so
    // first, then goes
    function hide(): void {
        touch();
        say(line("hide", ""), 1500);
        hideLater.restart();
    }

    Timer {
        id: hideLater

        interval: 1500
        onTriggered: {
            root.called = false;
            root.peeking = false;
            life.hiddenUntil = Date.now() + 3600000;
            root.now = Date.now();
        }
    }

    // ---- your own phrases, for each language
    readonly property var own: life.own ?? ({})

    function addPhrase(text: string): void {
        text = text.trim();
        if (!text)
            return;
        const o = Object.assign({}, own);
        o[lang] = [...(o[lang] ?? []), text.slice(0, 120)];
        life.own = o;
    }

    function removePhrase(i: int): void {
        const o = Object.assign({}, own);
        o[lang] = (o[lang] ?? []).filter((_, k) => k !== i);
        life.own = o;
    }

    // ---- the focus timer (services/Focus.qml): she keeps the time with you, says when it starts
    // and ends, and sits quietly in between (dnd keeps her from peeking out)
    readonly property string pomoPhase: Focus.phase === "work" ? "focus" : Focus.phase
    readonly property int pomoLeft: Focus.running ? Math.ceil(Focus.remaining / 60000) : 0

    function focus(): void {
        touch();
        if (Focus.running) {
            Focus.stop();
            say(line("pomoStop", ""), 0);
        } else {
            Focus.start(0);
        }
    }

    Connections {
        target: Focus

        function onStarted(): void {
            root.touch();
            root.say(root.line("pomoStart", ""), 0);
        }

        function onEnded(what: string): void {
            if (what === "work")
                root.react("pomoBreak", "", "hop", true);
            else
                root.react("pomoBack", "", "hop", true);
        }
    }

    // ------------------------------------------------------------------ where she is

    readonly property bool walks: Settings.companionMode !== "home"
    // out on an empty desktop (Bar.qml), asleep there too; called, she's in the corner instead
    readonly property bool onDesk: enabled && walks && !called && life.hiddenUntil < now && !Panels.locked

    // ------------------------------------------------------------------ what happens around

    readonly property var battery: UPower.displayDevice
    readonly property bool plugged: battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge
    readonly property bool batteryLow: battery.isLaptopBattery && !plugged && battery.percentage <= 0.05
    property var warned: []
    property bool settled: false // the first seconds: the starting values aren't news

    Timer {
        running: root.enabled
        interval: 5000
        onTriggered: root.settled = true
    }

    onPluggedChanged: {
        if (!settled || !battery.isLaptopBattery)
            return;
        if (plugged) {
            warned = [];
            react("charge", "", "hop", true);
        }
    }

    Connections {
        target: root.battery

        function onPercentageChanged(): void {
            if (!root.settled || !root.battery.isLaptopBattery || root.plugged)
                return;
            const pct = Math.round(root.battery.percentage * 100);
            for (const s of [5, 20]) {
                if (pct <= s && !root.warned.includes(s)) {
                    root.warned = [5, 20].filter(x => x >= s || root.warned.includes(x));
                    root.react(s === 5 ? "battery5" : "battery20", "", "alarm", true);
                    break;
                }
            }
        }
    }

    onRecordingChanged: if (recording && settled)
        react("rec", "", "glitch", true)

    Connections {
        target: root.enabled ? Screenshot : null

        function onTaken(): void {
            root.react("shot", "", "hop", true);
        }
    }

    Connections {
        target: root.enabled ? Todo : null

        function onDueNow(text: string): void {
            root.react("todo", text, "flag", true);
        }
    }

    // a task ticked off. Counted once both files are read: the list coming in at the start
    // isn't news
    readonly property int doneCount: Todo.loaded && loaded ? Todo.tasks.filter(t => t.done).length : -1
    property int doneSeen: -1

    Component.onCompleted: doneSeen = doneCount
    onDoneCountChanged: {
        if (enabled && doneSeen >= 0 && doneCount > doneSeen)
            react("todoDone", "", "hop", false);
        doneSeen = doneCount;
    }

    Connections {
        target: root.enabled ? Update : null

        function onFound(count: int): void {
            root.react("update", "", "hop", true);
        }
    }

    // a new kawt since she last looked
    readonly property string version: enabled ? Update.version.split(" ")[0] : ""

    onVersionChanged: {
        if (!version || !loaded)
            return;
        if (life.seen && life.seen !== version)
            lvlUp.restart();
        life.seen = version;
    }

    Timer {
        id: lvlUp

        interval: 6000
        onTriggered: root.react("updated", "", "glitch", true)
    }

    Connections {
        target: Panels

        // locked: you're away, she sleeps (Panels.locked is part of `sleeping`); back: hello
        function onLockedChanged(): void {
            if (!root.enabled)
                return;
            if (Panels.locked) {
                root.called = false;
                root.peeking = false;
            } else {
                root.touch();
                root.say(root.line("hello", ""), 0);
            }
        }
    }

    // ------------------------------------------------------------------ ipc

    function command(what: string): void {
        if (what === "toggle")
            Settings.companion = !Settings.companion;
        else if (!enabled || !loaded)
            return;
        else if (what === "pet")
            talkNow();
        else if (what === "call")
            call();
        else if (what === "sleep")
            sleep();
        else if (what === "wake")
            wake();
        else if (what === "focus")
            focus();
        else if (what === "walk" || what === "home")
            Settings.companionMode = what;
    }

    // ------------------------------------------------------------------ her file

    property bool loaded: false

    FileView {
        path: root.enabled ? `${Settings.dir}/companion.json` : ""
        printErrors: false // missing until the first day
        blockWrites: true // at once: in the background a quick second change was undone (config/Settings.qml)
        property bool readable: true // see utils/Saved.qml
        watchChanges: !readable
        onFileChanged: reload()
        onAdapterUpdated: if (readable)
            writeAdapter()
        onLoaded: {
            readable = Saved.readable(text(), path);
            root.loaded = true;
            if (root.version && life.seen !== root.version) {
                if (life.seen)
                    lvlUp.restart();
                life.seen = root.version;
            }
        }
        onLoadFailed: err => {
            root.loaded = true;
            if (err === FileViewError.FileNotFound)
                life.born = Date.now();
        }

        // (the pixel friend before her kept his food, fun and sleep here: gone with him)
        JsonAdapter {
            id: life

            property real born: 0 // when you met
            property real hiddenUntil: 0 // a double click: off the desktop for an hour
            property real deskAt: 0.15 // where on the desktop she was left, 0..1 of the width
            property string nightOn: "" // the night she last yawned
            property string seen: "" // the kawt version she last saw
            property var own: ({}) // your phrases for her: { en: [...], ru: [...] }
        }
    }

    readonly property real born: life.born
    property alias deskAt: life.deskAt
}
