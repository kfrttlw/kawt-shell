pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

// kawt's own updates (profile -> cfg -> kawt). Knowing whether there's a new version means
// asking github: [check] does that once (git fetch), and Settings.updateAuto (on by default)
// does it by itself once a week, saying so in a notification only when there's something new
// (the companion jumps: lvl up). Off: nothing goes out unless [check] is pressed. [update]
// opens a terminal with ./install.sh --update, which shows what's new and asks before it
// changes anything (and may need sudo for a new package).
//   qs -c kawt-shell ipc call kawt update
Singleton {
    id: root

    readonly property real week: 7 * 24 * 3600000
    property string repo: "" // the clone ~/.config/quickshell/kawt-shell links into
    property string version: "" // "2b47871 · 3 days ago"
    property int behind: -1 // new commits upstream; -1 = not asked yet
    property string news: "" // the newest of their titles
    property string status: ""
    readonly property bool checking: checker.running

    // the weekly check found a version it hadn't told about yet
    signal found(int count)

    // auto: the weekly check, which says so in a notification (the panel isn't open to show it)
    function check(auto: bool): void {
        if (!repo || checker.running)
            return;
        checker.auto = !!auto;
        status = "asking the remote...";
        // the branch it follows gone from the remote (dev, merged and deleted): what main has
        // that this doesn't, which [update] moves it to (install.sh --update)
        checker.command = ["sh", "-c", 'cd "$1" || exit 1; export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes"; git fetch -q --prune || exit 1; u="@{u}"; git rev-parse -q --verify "$u" > /dev/null || u=origin/main; git rev-list --count "HEAD..$u" && git rev-parse "$u" && git log --no-merges --format=%s -n 1 "HEAD..$u"', "sh", repo];
        checker.running = true;
    }

    // in a terminal: it shows what's new, asks, and may need your password for pacman
    function run(): void {
        if (repo)
            Apps.runInTerminal(`'${repo.replace(/'/g, "'\\''")}/install.sh' --update`);
    }

    // where the clone is, and what it's at: the shell's folder is a link into it
    Process {
        id: locate

        running: true
        command: ["sh", "-c", 'd=$(readlink -f "$1") && cd "$d/../.." && git rev-parse --show-toplevel && git log -1 --format="%h · %cr"', "sh", Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.repo = lines.length === 2 ? lines[0] : "";
                root.version = lines.length === 2 ? lines[1] : "";
            }
        }
    }

    // "3" (new commits), the upstream commit, the newest title
    Job {
        id: checker

        property bool auto: false

        onDone: (code, out) => {
            const lines = out.trim().split("\n");
            if (code !== 0 || !/^\d+$/.test(lines[0] ?? "")) {
                // the weekly one stays due: tried again next hour, quietly
                root.status = "couldn't ask: no internet, or the branch follows no remote one";
                return;
            }
            Settings.updateCheckedAt = Date.now();
            root.behind = parseInt(lines[0]);
            root.news = root.behind > 0 ? (lines[2] ?? "") : "";
            root.status = root.behind === 0 ? "up to date" : `${root.behind} new`;
            // once per new upstream state: a version you skipped isn't brought up every week
            if (auto && root.behind > 0 && Settings.updateNotified !== lines[1]) {
                Settings.updateNotified = lines[1];
                asker.running = false;
                asker.command = ["notify-send", "-a", "kawt", "-A", "update=update", "-A", "default=update", `kawt: ${root.status}`, root.news];
                asker.running = true;
                root.found(root.behind);
            }
        }
    }

    // the notification's [update] (or a click on it, in the log too) runs the update;
    // nothing comes when it's dismissed. notify-send -A waits for it
    Process {
        id: asker

        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                root.run()
        }
    }

    // Settings.updateAuto: a week after the last check (looked at hourly, so a machine that
    // sleeps a lot still gets it; the time is kept, so a restart doesn't ask again). A new
    // install starts counting from now: it's up to date. Only once the settings are read: before
    // that the time is the default 0, and writing it then could put every setting back to its default
    Timer {
        running: Settings.loaded && Settings.updateAuto && root.repo !== ""
        repeat: true
        interval: 3600000
        triggeredOnStart: true
        onTriggered: {
            if (!Settings.updateCheckedAt)
                Settings.updateCheckedAt = Date.now();
            if (Date.now() - Settings.updateCheckedAt >= root.week)
                root.check(true);
        }
    }
}
