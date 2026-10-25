pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

// kawt's own updates (profile -> cfg -> kawt). Nothing goes out by itself: [check] asks the
// remote once (git fetch), and only when pressed, unless Settings.updateCheck is on (off by
// default: then once a day). [update] opens a terminal with ./install.sh --update, which shows
// what's new and asks before it changes anything (and may need sudo for a new package).
//   qs -c kawt-shell ipc call kawt update
Singleton {
    id: root

    property string repo: "" // the clone ~/.config/quickshell/kawt-shell links into
    property string version: "" // "2b47871 · 3 days ago"
    property int behind: -1 // new commits upstream; -1 = not asked yet
    property string news: "" // the newest of their titles
    property string status: ""
    readonly property bool checking: checker.running

    // auto: the daily check (Settings.updateCheck), which says so in a notification
    function check(auto: bool): void {
        if (!repo || checker.running)
            return;
        checker.auto = !!auto;
        status = "asking the remote...";
        checker.command = ["sh", "-c", 'cd "$1" || exit 1; export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes"; git fetch -q || exit 1; git rev-list --count "HEAD..@{u}" && git rev-parse "@{u}" && git log --no-merges --format=%s -n 1 "HEAD..@{u}"', "sh", repo];
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
                root.status = "couldn't ask: no internet, or the branch follows no remote one";
                return;
            }
            root.behind = parseInt(lines[0]);
            root.news = root.behind > 0 ? (lines[2] ?? "") : "";
            root.status = root.behind === 0 ? "up to date" : `${root.behind} new`;
            // the daily check says so once per new upstream state, not every day again
            if (auto && root.behind > 0 && Settings.updateNotified !== lines[1]) {
                Settings.updateNotified = lines[1];
                Quickshell.execDetached(["notify-send", "-a", "kawt", `kawt: ${root.status}`, "profile -> cfg -> [update]"]);
            }
        }
    }

    // Settings.updateCheck: once a day (looked at hourly, so a machine that sleeps a lot still
    // gets it); the time of the last one is kept, so a restart doesn't ask again
    Timer {
        running: Settings.updateCheck && root.repo !== ""
        repeat: true
        interval: 3600000
        triggeredOnStart: true
        onTriggered: {
            if (Date.now() - Settings.updateCheckedAt < 23 * 3600000)
                return;
            Settings.updateCheckedAt = Date.now();
            root.check(true);
        }
    }
}
