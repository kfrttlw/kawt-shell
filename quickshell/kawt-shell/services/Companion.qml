pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.config
import "../utils/companions.js" as Art

// The companion: a few pixels with a house in the bar ([home]). He walks about an empty
// desktop, sits next to the coder, and peeks out of the corner when something happens
// (the battery, a screenshot, a reminder, a new kawt). He gets hungry, bored and sleepy with
// time, all worked out from when it last happened: nothing ticks for it, and nothing moves
// while he's nowhere on the screen. He never dies or runs off: left alone too long he sulks,
// and food and a game bring him round.
//
//   Settings.companion       on / off (off: no house, no walks, no peeks)
//   Settings.companionMode   "home" | "walk" (an empty desktop is his) | "auto" (he decides)
//   Settings.companionAsks   asks for food and play in a notification (3 times a day at most)
//   Settings.companionSkin   a look from utils/companions.js, or yours (~/.config/kawt/companions.json)
//   Settings.companionName   "" = the look's own
//   Settings.companionLang   "en" | "ru": what he says
// His life (food, fun, sleep, your phrases for him) is in ~/.local/state/kawt/companion.json.
//   qs -c kawt-shell ipc call kawt companion feed|play|sleep|wake|pet|focus|home|walk|auto|toggle
Singleton {
    id: root

    readonly property bool enabled: Settings.companion
    readonly property string lang: Settings.companionLang === "ru" ? "ru" : "en"

    // ------------------------------------------------------------------ looks

    property var custom: ({}) // ~/.config/kawt/companions.json, the valid ones
    readonly property var skins: Object.assign({}, Art.skins, custom, { theme: Object.assign({}, Art.skins.theme, { colors: themeColors }) })
    readonly property var order: Art.order.concat(Object.keys(custom).filter(k => !Art.order.includes(k)))
    readonly property string skinName: skins[Settings.companionSkin] ? Settings.companionSkin : "phos"
    readonly property var skin: skins[skinName]
    readonly property string name: Settings.companionName || title(skinName)

    function title(k: string): string {
        const n = skins[k]?.name;
        return typeof n === "string" ? n : (n && (n[lang] || n.en)) || k;
    }

    function mix(a: color, b: color, t: real): string {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1).toString();
    }

    readonly property var themeColors: ({
        o: Colors.border.toString(),
        b: mix(Colors.bg, Colors.accent, 0.35),
        l: Colors.accent.toString(),
        s: Colors.bg.toString(),
        e: Colors.fg.toString(),
        m: Colors.bg.toString(),
        a: Colors.accent.toString(),
        h: Colors.dim.toString(),
        c: Colors.border.toString()
    })

    // letter -> color, for a sprite (skins can't change the warn color or the props)
    function paletteOf(s: var): var {
        const c = s?.colors ?? {};
        const p = Object.assign({ f: "#e0a040", k: Colors.border.toString(), r: "#8a5a2b", y: "#d9c06a", g: Colors.warn.toString() }, c);
        p.h = c.h ?? c.o;
        p.c = c.c ?? c.o;
        p.w = Colors.warn.toString();
        // the red light on his antenna while the screen is recorded
        if (recording)
            p.a = Colors.warn.toString();
        return p;
    }

    readonly property bool recording: Recorder.recording

    FileView {
        path: root.enabled ? `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kawt/companions.json` : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let all = {};
            try {
                all = JSON.parse(text());
            } catch (e) {
                console.warn("companions.json: not valid json");
            }
            const ok = {};
            for (const k of Object.keys(all ?? {}))
                if (/^[a-z0-9-]+$/.test(k) && k !== "theme" && Art.valid(all[k]))
                    ok[k] = all[k];
                else
                    console.warn(`companions.json: "${k}" skipped (10 rows of 12 letters, colors as #rrggbb)`);
            root.custom = ok;
        }
        onLoadFailed: root.custom = ({})
    }

    // ------------------------------------------------------------------ needs

    // the clock his needs are read with: once a minute is plenty (and at every action)
    property real now: Date.now()
    readonly property real foodSpan: 16 * 3600000 // full to empty
    readonly property real funSpan: 12 * 3600000
    readonly property real awakeSpan: 18 * 3600000
    readonly property real restSpan: 3 * 3600000 // empty to rested, asleep

    function decay(n: var, span: real): real {
        if (!n || n.at === undefined)
            return 1;
        return Math.max(0, Math.min(1, n.v - (now - n.at) / span));
    }

    readonly property bool sleeping: life.sleeping
    readonly property real born: life.born
    readonly property real food: decay(life.food, foodSpan)
    readonly property real fun: decay(life.fun, funSpan)
    readonly property real energy: !life.energy?.at ? 1 : sleeping ? Math.min(1, life.energy.v + (now - life.energy.at) / restSpan) : decay(life.energy, awakeSpan)
    readonly property bool sulking: !sleeping && (food < 0.15 || fun < 0.15)
    // what he'd like: the house shows it, the bar gets a "!"
    readonly property string wants: sleeping ? "" : food < 0.3 ? "food" : fun < 0.3 ? "play" : energy < 0.15 ? "sleep" : ""
    readonly property string mood: sleeping ? "asleep" : sulking ? "sulking" : wants === "food" ? "hungry" : wants === "play" ? "bored" : wants === "sleep" ? "tired" : food > 0.6 && fun > 0.6 ? "happy" : "fine"

    // ------------------------------------------------------------------ moving

    property alias deskAt: life.deskAt // where on the desktop he was left, 0..1 of the width
    property int viewers: 0 // sprites on the screen right now (modules/companion/Pet.qml)
    property int deskViews: 0 // the desktop one among them: then he's out, not home
    property int step: 0
    property bool blink: false
    readonly property bool music: Mpris.players.values.some(p => p.isPlaying)
    property string act: "" // a move for a few seconds: eat, jump, wave...
    readonly property bool batteryLow: battery.isLaptopBattery && !plugged && battery.percentage <= 0.05
    // what he does when nothing else is asked of him (the desktop adds walking and dancing)
    readonly property string base: act || (sleeping ? "sleep" : batteryLow ? "alarm" : sulking ? "sulk" : energy < 0.15 ? "yawn" : "idle")

    Timer {
        running: root.viewers > 0 && !Panels.locked
        repeat: true
        interval: 220
        onTriggered: root.step++
    }

    // a blink every few seconds
    Timer {
        id: blinker

        running: root.viewers > 0 && !Panels.locked
        interval: 3000
        onTriggered: {
            root.blink = !root.blink;
            interval = root.blink ? 150 : 2500 + Math.random() * 4000;
            restart();
        }
    }

    Timer {
        id: actTimer

        onTriggered: root.act = ""
    }

    function move(anim: string, ms: int): void {
        act = anim;
        actTimer.interval = ms || 3000;
        actTimer.restart();
    }

    // ------------------------------------------------------------------ talking

    property string said: "" // the bubble over him
    property real saidAt: 0

    Timer {
        id: hush

        interval: 4500
        onTriggered: root.said = ""
    }

    function line(kind: string, arg: var): string {
        const t = Art.talk[lang] ?? Art.talk.en;
        let list = t[kind] ?? Art.talk.en[kind] ?? [];
        // your phrases come up as often as all of his together
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

    // something happened: a move and a line, wherever he is on the screen. If he's nowhere
    // on it, he peeks out of the corner (not over a fullscreen window, not in dnd, not hidden)
    function react(kind: string, arg: string, anim: string, peek: bool): void {
        if (!enabled)
            return;
        if (anim && !sleeping)
            move(anim, 3500);
        say(line(kind, arg), 0);
        if (peek && (viewers === 0 || peeking) && canPeek && !sleeping) {
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

    // a click on him: how he is, what's next, or a word of his
    function talkNow(): void {
        if (sleeping) {
            say("zzz", 1500);
            return;
        }
        touch();
        if (sulking) {
            say(line("sulk", ""), 0);
            return;
        }
        const r = Math.random();
        if (wants && r < 0.5)
            say(line(wants === "food" ? "hungry" : wants === "play" ? "bored" : "sleepy", ""), 0);
        else if (r < 0.15 && battery.isLaptopBattery)
            say(line("battery", `${Math.round(battery.percentage * 100)}%${plugged ? "+" : ""}`), 0);
        else if (r < 0.3 && nextTask())
            say(line("next", nextTask()), 0);
        else if (night && r < 0.6)
            say(line("night", ""), 0);
        else
            say(line("chat", ""), 0);
        // a little fun from the attention, once a minute at most
        if (Date.now() - petAt > 60000) {
            petAt = Date.now();
            set("fun", fun + 0.03);
        }
        move("wave", 1500);
    }

    property real petAt: 0

    function nextTask(): string {
        const t = Todo.today[0];
        return t ? `${t.text} · ${Time.fmt(new Date(t.due))}` : "";
    }

    // ------------------------------------------------------------------ what you do

    function touch(): void {
        now = Date.now();
    }

    function set(key: string, v: real): void {
        life[key] = { v: Math.max(0, Math.min(1, v)), at: Date.now() };
        touch();
    }

    function feed(): void {
        touch();
        if (sleeping) {
            wake();
            return;
        }
        if (food > 0.9) {
            say(line("full", ""), 0);
            return;
        }
        const foods = (Art.talk[lang] ?? Art.talk.en).foods;
        const what = foods[life.meal % foods.length];
        life.meal = life.meal + 1;
        set("food", food + 0.35);
        set("fun", fun + 0.05);
        move("eat", 3000);
        say(line("eat", what), 0);
        afterCare();
    }

    function play(): void {
        touch();
        if (sleeping) {
            wake();
            return;
        }
        if (energy < 0.15) {
            say(line("tired", ""), 0);
            move("yawn", 2500);
            return;
        }
        set("fun", fun + 0.4);
        set("energy", energy - 0.05);
        move("jump", 3500);
        say(line("play", ""), 0);
        afterCare();
    }

    // fed and played with after a sulk: he says so
    function afterCare(): void {
        if (!sulking && food > 0.3 && fun > 0.3 && life.wasSulking) {
            life.wasSulking = false;
            say(line("thanks", ""), 0);
        }
    }

    function sleep(auto: bool): void {
        touch();
        if (sleeping)
            return;
        life.energy = { v: energy, at: Date.now() };
        life.sleeping = true;
        act = "";
        actTimer.stop();
        life.sleptBy = auto ? "auto" : "you";
        if (!auto)
            say(line("sleep", ""), 2000);
    }

    function wake(): void {
        touch();
        if (!sleeping)
            return;
        const e = energy, long = Date.now() - (life.energy?.at ?? 0) > 4 * 3600000;
        life.energy = { v: e, at: Date.now() };
        life.sleeping = false;
        say(line(e < 0.3 ? "grumpy" : long ? "woke" : "hello", ""), 0);
        if (e >= 0.3)
            move("stretch", 1800);
    }

    // off the desktop and out of the corners for an hour (a double click on him)
    function hide(): void {
        touch();
        say(line("hide", ""), 2500);
        life.hiddenUntil = Date.now() + 3600000;
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

    // ---- pomodoro: 25 minutes of focus, 5 of rest; he keeps the time with you
    readonly property string pomoPhase: life.pomo?.phase ?? ""
    readonly property int pomoLeft: pomoPhase ? Math.max(0, Math.ceil((life.pomo.until - now) / 60000)) : 0

    function focus(): void {
        touch();
        if (pomoPhase) {
            life.pomo = ({});
            pomoTimer.stop();
            say(line("pomoStop", ""), 0);
            return;
        }
        life.pomo = { phase: "focus", until: now + 25 * 60000 };
        say(line("pomoStart", ""), 0);
        schedulePomo();
    }

    function schedulePomo(): void {
        if (!pomoPhase) {
            pomoTimer.stop();
            return;
        }
        pomoTimer.interval = Math.max(1000, life.pomo.until - Date.now());
        pomoTimer.restart();
    }

    Timer {
        id: pomoTimer

        onTriggered: {
            root.touch();
            if (root.pomoPhase === "focus") {
                life.pomo = { phase: "break", until: root.now + 5 * 60000 };
                root.react("pomoBreak", "", "stretch", true);
                root.schedulePomo();
            } else if (root.pomoPhase === "break") {
                life.pomo = ({});
                root.react("pomoBack", "", "wave", true);
            }
        }
    }

    // ------------------------------------------------------------------ where he is

    // home, or out on an empty desktop: "auto" goes out when he feels like it, in the day
    readonly property bool outside: Settings.companionMode === "walk" || (Settings.companionMode === "auto" && life.out)
    readonly property bool onDesk: enabled && outside && !sleeping && !sulking && life.hiddenUntil < now && !Panels.locked
    readonly property bool night: {
        const h = new Date(now).getHours();
        return h >= 1 && h < 5;
    }

    // the minute: needs, asking, a walk or not, sleep, the night. Only once his file is read:
    // a change before that would be written over the file and lose his life
    Timer {
        running: root.enabled && root.loaded
        repeat: true
        interval: 60000
        triggeredOnStart: true
        onTriggered: root.minute()
    }

    function minute(): void {
        touch();
        const h = new Date(now).getHours();
        if (sulking)
            life.wasSulking = true;
        // rested: up by himself; worn out: asleep by himself
        if (sleeping && energy >= 1 && !Panels.locked)
            wake();
        else if (!sleeping && energy <= 0.02)
            sleep(true);
        // "auto": every half hour he thinks about going out
        if (now - (life.outAt ?? 0) > 30 * 60000) {
            life.outAt = now;
            life.out = h >= 8 && h < 23 && !sulking && Math.random() < (mood === "happy" ? 0.7 : 0.4);
        }
        // once a night: a yawn from the corner
        const today = Qt.formatDate(new Date(now), "yyyy-MM-dd");
        if (night && life.nightOn !== today && !sleeping && canPeek) {
            life.nightOn = today;
            react("night", "", "yawn", true);
        }
        askIfNeeded(h, today);
    }

    // a notification with a button: [feed] / [play] / [sleep]. Not at night, not in dnd,
    // not over a fullscreen window, three hours apart and three times a day at most
    function askIfNeeded(h: int, today: string): void {
        if (!Settings.companionAsks || !wants || asker.running || Settings.dnd || Panels.locked || fullscreen || h < 9 || h >= 23)
            return;
        if (now - (life.askedAt ?? 0) < 3 * 3600000)
            return;
        const count = life.askedDay === today ? life.asked : 0;
        if (count >= 3)
            return;
        life.askedAt = now;
        life.askedDay = today;
        life.asked = count + 1;
        const what = wants === "food" ? "feed" : wants === "play" ? "play" : "sleep";
        asker.action = what;
        asker.command = ["notify-send", "-a", name, "-A", `${what}=${what}`, "-A", `default=${what}`, name, line(wants === "food" ? "hungry" : wants === "play" ? "bored" : "sleepy", "")];
        asker.running = true;
    }

    // the button (or a click on the notification) does it; nothing comes when it's dismissed
    Process {
        id: asker

        property string action: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "")
                    return;
                if (asker.action === "feed")
                    root.feed();
                else if (asker.action === "play")
                    root.play();
                else
                    root.sleep(false);
                root.peeking = root.canPeek;
                peekTimer.restart();
            }
        }
    }

    // ------------------------------------------------------------------ what happens around

    readonly property var battery: UPower.displayDevice
    readonly property bool plugged: battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge
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
            react("charge", "", "happy", true);
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
        react("rec", "", "wave", true)

    onMusicChanged: if (music && settled && !sleeping && viewers > 0)
        move("dance", 2500)

    Connections {
        target: root.enabled ? Screenshot : null

        function onTaken(): void {
            root.react("shot", "", "happy", true);
        }
    }

    Connections {
        target: root.enabled ? Todo : null

        function onDueNow(text: string): void {
            root.react("todo", text, "flag", true);
        }
    }

    // a task ticked off
    readonly property int doneCount: Todo.tasks.filter(t => t.done).length
    property int doneSeen: -1

    Component.onCompleted: doneSeen = doneCount
    onDoneCountChanged: {
        if (enabled && doneSeen >= 0 && doneCount > doneSeen) {
            react("todoDone", "", "happy", false);
            set("fun", fun + 0.1);
        }
        doneSeen = doneCount;
    }

    Connections {
        target: root.enabled ? Update : null

        function onFound(count: int): void {
            root.react("update", "", "jump", true);
        }
    }

    // a new kawt since he last looked: lvl up
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
        onTriggered: root.react("updated", "", "jump", true)
    }

    Connections {
        target: Panels

        // locked: you're away, he naps; back: he's up again if he only napped for that
        function onLockedChanged(): void {
            if (!root.enabled || !root.loaded)
                return;
            if (Panels.locked && !root.sleeping) {
                root.sleep(true);
            } else if (!Panels.locked && root.sleeping && life.sleptBy === "auto" && root.energy > 0.3) {
                root.wake();
            }
        }
    }

    // ------------------------------------------------------------------ ipc

    function command(what: string): void {
        if (what === "toggle")
            Settings.companion = !Settings.companion;
        else if (!enabled || !loaded)
            return;
        else if (what === "feed")
            feed();
        else if (what === "play")
            play();
        else if (what === "sleep")
            sleep(false);
        else if (what === "wake")
            wake();
        else if (what === "pet")
            talkNow();
        else if (what === "focus")
            focus();
        else if (["home", "walk", "auto"].includes(what))
            Settings.companionMode = what;
    }

    // ------------------------------------------------------------------ his file

    property bool loaded: false

    FileView {
        path: root.enabled ? `${Settings.dir}/companion.json` : ""
        printErrors: false // missing until his first day
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root.loaded = true;
            root.schedulePomo();
            if (root.version && life.seen !== root.version) {
                if (life.seen)
                    lvlUp.restart();
                life.seen = root.version;
            }
        }
        onLoadFailed: err => {
            root.loaded = true;
            if (err === FileViewError.FileNotFound) {
                // his first day: full, rested, happy
                const t = Date.now();
                life.food = { v: 1, at: t };
                life.fun = { v: 1, at: t };
                life.energy = { v: 1, at: t };
                life.born = t;
            }
        }

        JsonAdapter {
            id: life

            property var food: ({}) // { v: 0..1, at: ms }
            property var fun: ({})
            property var energy: ({})
            property bool sleeping: false
            property string sleptBy: "" // "auto" (the lock, worn out) | "you"
            property real born: 0
            property int meal: 0 // which food comes next
            property bool wasSulking: false
            property bool out: true // "auto": out on the desktop now
            property real outAt: 0
            property real hiddenUntil: 0 // a double click: off the desktop for an hour
            property real deskAt: 0.15
            property real askedAt: 0
            property string askedDay: ""
            property int asked: 0
            property string nightOn: ""
            property string seen: "" // the kawt version he last saw
            property var pomo: ({}) // { phase: "focus" | "break", until: ms }
            property var own: ({}) // { en: [...], ru: [...] }
        }
    }
}
