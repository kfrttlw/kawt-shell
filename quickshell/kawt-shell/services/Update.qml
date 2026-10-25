pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

// kawt's own updates (profile -> cfg -> kawt). Nothing goes out by itself: [check] asks the
// remote once (git fetch, to github), and only when pressed. Settings.updateRemind (on by
// default) only reminds: once a week a notification with [check] on it, made without going
// anywhere. [update] opens a terminal with ./install.sh --update, which shows what's new and
// asks before it changes anything (and may need sudo for a new package).
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

    // tell: say the answer in a notification ([check] on the reminder: no panel open to show it)
    function check(tell: bool): void {
        if (!repo || checker.running)
            return;
        checker.tell = !!tell;
        status = "asking the remote...";
        checker.command = ["sh", "-c", 'cd "$1" || exit 1; export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes"; git fetch -q || exit 1; git rev-list --count "HEAD..@{u}" && git log --no-merges --format=%s -n 1 "HEAD..@{u}"', "sh", repo];
        checker.running = true;
    }

    // in a terminal: it shows what's new, asks, and may need your password for pacman
    function run(): void {
        if (repo)
            Apps.runInTerminal(`'${repo.replace(/'/g, "'\\''")}/install.sh' --update`);
    }

    // a notification with one button; pressing it, or clicking the notification (in the log
    // too, after the toast is gone), does that. notify-send -A waits for it
    function ask(title: string, body: string, action: string): void {
        asker.running = false;
        asker.action = action;
        asker.command = ["notify-send", "-a", "kawt", "-A", `${action}=${action}`, "-A", `default=${action}`, title, body];
        asker.running = true;
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

    // "3" (new commits), the newest title
    Job {
        id: checker

        property bool tell: false

        onDone: (code, out) => {
            const lines = out.trim().split("\n");
            if (code !== 0 || !/^\d+$/.test(lines[0] ?? "")) {
                root.status = "couldn't ask: no internet, or the branch follows no remote one";
                if (tell)
                    Quickshell.execDetached(["notify-send", "-a", "kawt", "kawt: couldn't check", "no internet, or the branch follows no remote one"]);
                return;
            }
            // just checked: the weekly reminder starts counting again
            Settings.updateCheckedAt = Date.now();
            root.behind = parseInt(lines[0]);
            root.news = root.behind > 0 ? (lines[1] ?? "") : "";
            root.status = root.behind === 0 ? "up to date" : `${root.behind} new`;
            if (!tell)
                return;
            if (root.behind > 0)
                root.ask(`kawt: ${root.status}`, root.news, "update");
            else
                Quickshell.execDetached(["notify-send", "-a", "kawt", "kawt: up to date"]);
        }
    }

    // one of ask()'s notifications was pressed (nothing comes when it's dismissed)
    Process {
        id: asker

        property string action: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "")
                    return;
                if (asker.action === "check")
                    root.check(true);
                else if (asker.action === "update")
                    root.run();
            }
        }
    }

    // Settings.updateRemind: a week after the last check or reminder (looked at hourly; the time
    // is kept, so a restart doesn't remind again). A new install starts counting from now
    Timer {
        running: Settings.updateRemind && root.repo !== ""
        repeat: true
        interval: 3600000
        triggeredOnStart: true
        onTriggered: {
            if (!Settings.updateCheckedAt)
                Settings.updateCheckedAt = Date.now();
            // last week's is still in the log, unanswered: that one will do
            if (Date.now() - Settings.updateCheckedAt < root.week || asker.running)
                return;
            Settings.updateCheckedAt = Date.now();
            root.ask("kawt: look for updates?", "it's been a week. [check] asks github once", "check");
        }
    }
}
