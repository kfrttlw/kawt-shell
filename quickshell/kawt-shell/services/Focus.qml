pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The focus timer (profile -> focus and today, the companion's house, `kawt focus`): a stretch of
// work, then a break. On a task of the todo list if you like, or on nothing in particular.
//   while it works   do not disturb is on (back as it was after, unless you changed it meanwhile)
//                    and the companion sits quietly: dnd keeps him from peeking out
//   at the end       a notification ("3 of 4 today") and the companion says it; the break runs by
//                    itself, after it the next round waits for you
// Each finished round is counted per day in ~/.local/state/kawt/focus.json (the week's chart),
// with what's running now: a restart of kawt (or of the machine) carries on where it was.
// Times are the machine's own (Date.now), not the shell clock: moving that doesn't stretch a round.
Singleton {
    id: root

    readonly property string phase: adapter.phase // "" | "work" | "break"
    readonly property bool running: phase !== ""
    readonly property bool paused: adapter.pausedLeft > 0
    readonly property int workMin: adapter.workMin
    readonly property int breakMin: adapter.breakMin
    readonly property int goal: adapter.goal
    readonly property bool quiet: adapter.quiet
    readonly property real taskId: adapter.task
    readonly property string taskText: adapter.taskText

    // the clock, a tick a second while a round runs (nothing at all otherwise)
    property real now: Date.now()
    readonly property real total: (phase === "break" ? breakMin : workMin) * 60000
    readonly property real remaining: !running ? 0 : paused ? adapter.pausedLeft : Math.max(0, adapter.until - now)
    readonly property real progress: running && total > 0 ? Math.min(1, 1 - remaining / total) : 0
    // "18:42"
    readonly property string clock: {
        const s = Math.ceil(remaining / 1000);
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    // ---- the days: { "2026-10-28": [rounds, ms of work] }
    readonly property var days: adapter.days
    readonly property string today: Qt.formatDate(new Date(now), "yyyy-MM-dd")
    readonly property int todayRounds: (days[today] ?? [0, 0])[0]
    readonly property real todayMs: (days[today] ?? [0, 0])[1]
    // this week, monday first: [{ day: "mon", rounds, isToday }]
    readonly property var week: {
        const d = new Date(now);
        const monday = new Date(d.getFullYear(), d.getMonth(), d.getDate() - (d.getDay() + 6) % 7);
        const out = [];
        for (let i = 0; i < 7; i++) {
            const day = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i);
            const key = Qt.formatDate(day, "yyyy-MM-dd");
            out.push({ day: Qt.formatDate(day, "ddd").toLowerCase(), rounds: (days[key] ?? [0])[0], isToday: key === today });
        }
        return out;
    }

    // a round ended: "work" (one more done) or "break"; the companion answers
    signal ended(string what)
    signal started

    // ---- what you do with it

    // a round of work, on a task (its id; 0: none)
    function start(task: real): void {
        const t = task ? Todo.tasks.find(x => x.id === task) : null;
        adapter.task = t ? t.id : 0;
        adapter.taskText = t ? t.text : "";
        begin("work");
        started();
    }

    // the companion's [focus] and `kawt focus`: on, or off again
    function toggle(): void {
        if (running)
            stop();
        else
            start(0);
    }

    function pause(): void {
        if (!running || paused)
            return;
        adapter.pausedLeft = Math.max(1000, adapter.until - Date.now());
        schedule();
    }

    function resume(): void {
        if (!paused)
            return;
        adapter.until = Date.now() + adapter.pausedLeft;
        adapter.pausedLeft = 0;
        schedule();
    }

    // the rest of this part is let go: work goes to its break (without counting), a break ends
    function skip(): void {
        if (phase === "work")
            begin("break");
        else if (phase === "break")
            finish();
    }

    function stop(): void {
        finish();
    }

    function setLengths(work: int, rest: int): void {
        adapter.workMin = work;
        adapter.breakMin = rest;
    }

    function setGoal(n: int): void {
        adapter.goal = Math.max(1, Math.min(16, n));
    }

    function setQuiet(on: bool): void {
        adapter.quiet = on;
        if (phase === "work")
            on ? hush() : unhush();
    }

    // ---- inside

    function begin(what: string): void {
        adapter.phase = what;
        adapter.pausedLeft = 0;
        adapter.until = Date.now() + (what === "break" ? breakMin : workMin) * 60000;
        now = Date.now();
        if (what === "work" && quiet)
            hush();
        else
            unhush();
        schedule();
    }

    function finish(): void {
        unhush();
        adapter.phase = "";
        adapter.pausedLeft = 0;
        adapter.until = 0;
        schedule();
    }

    // dnd on for the work, and what it was before kept (also over a restart)
    function hush(): void {
        if (adapter.dndBefore !== -1)
            return;
        adapter.dndBefore = Settings.dnd ? 1 : 0;
        Settings.dnd = true;
    }

    function unhush(): void {
        if (adapter.dndBefore === -1)
            return;
        // switched off by hand meanwhile: left off; on before: left on
        if (adapter.dndBefore === 0 && Settings.dnd)
            Settings.dnd = false;
        adapter.dndBefore = -1;
    }

    function partDone(): void {
        if (phase === "work") {
            const d = Object.assign({}, adapter.days);
            const was = d[today] ?? [0, 0];
            d[today] = [was[0] + 1, was[1] + workMin * 60000];
            // a year of days is plenty for any chart
            const keys = Object.keys(d).sort();
            for (const k of keys.slice(0, Math.max(0, keys.length - 370)))
                delete d[k];
            adapter.days = d;
            const n = d[today][0];
            notify(`focus done · ${n} of ${goal} today`, `${breakMin} min break${taskText ? ` · ${taskText}` : ""}`);
            begin("break");
            ended("work");
        } else if (phase === "break") {
            notify("break's over", "the next round: profile -> focus");
            finish();
            ended("break");
        }
    }

    function notify(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "focus", "-e", title, body]);
    }

    // the end of the running part, to the second; nothing while paused or stopped
    function schedule(): void {
        if (!running || paused || !loaded) {
            ender.stop();
            return;
        }
        ender.interval = Math.max(500, adapter.until - Date.now());
        ender.restart();
    }

    Timer {
        id: ender

        onTriggered: {
            root.now = Date.now();
            if (root.now >= adapter.until - 400)
                root.partDone();
            else
                root.schedule(); // woke early (the timer's count stops while the machine sleeps)
        }
    }

    Timer {
        running: root.running && !root.paused
        interval: 1000
        repeat: true
        onTriggered: {
            root.now = Date.now();
            // after a sleep the end may be long past: the timer above only counts awake time
            if (root.now >= adapter.until)
                root.partDone();
        }
    }

    property bool loaded: false

    FileView {
        path: `${Settings.dir}/focus.json`
        printErrors: false // there's none until the first round
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root.loaded = true;
            root.now = Date.now();
            root.schedule();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter

            property string phase: ""
            property real until: 0 // ms, the end of the running part
            property real pausedLeft: 0 // ms left while paused; 0: not paused
            property real task: 0
            property string taskText: ""
            property int workMin: 25
            property int breakMin: 5
            property int goal: 4 // rounds a day
            property bool quiet: true // dnd while working
            property int dndBefore: -1 // dnd before the work: 0 / 1; -1: kawt didn't touch it
            property var days: ({})
        }
    }
}
