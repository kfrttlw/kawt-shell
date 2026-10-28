import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils
import "../popovers"

// Everything inside the profile: tabs sys / top / todo / notes / cfg.
// Used by the small popover under [●] and by the full-screen dashboard (super + i).
ColumnLayout {
    id: root

    property bool open: false
    property ShellScreen forScreen: null
    property bool wide: false // the dashboard: more room, so cards sit side by side

    spacing: Metrics.spacing

    // "boot": the sys tab's blocks appear one after another when the profile opens
    property int boot: 0
    readonly property var upcoming: Todo.sorted.filter(t => !t.done)
    readonly property var next: Todo.sorted.find(t => !t.done && t.due > Time.now.getTime()) ?? null
    property string fortune: ""
    // todo tab: the folder on the left, and which task is opened
    property string todoFolder: "inbox"
    property real todoOpen: 0
    readonly property var todoTasks: Todo.inFolder(todoFolder)
    // notes tab: folder and opened note. Kept out here because the tabs themselves are made
    // anew each time they're shown (see the Loaders below)
    property string notesFolder: "notes"
    property real noteOpen: 0

    // 25m / 2h 10m / 3d
    function until(ms: real): string {
        const m = Math.max(0, Math.round((ms - Time.now.getTime()) / 60000));
        if (m < 60)
            return `${m}m`;
        if (m < 1440)
            return `${Math.floor(m / 60)}h${m % 60 ? ` ${m % 60}m` : ""}`;
        return `${Math.floor(m / 1440)}d`;
    }

    OpenWatch {
        open: root.open
        onOpened: {
            root.armed = "";
            root.boot = 0;
            bootTimer.restart();
            if (Settings.motto === "fortune")
                fortuneProc.running = true;
        }
        onClosed: {
            root.armed = "";
            Todo.saveNoteSoon(); // a task note typed but not clicked away from
        }
    }

    Timer {
        id: bootTimer

        interval: 70
        repeat: true
        onTriggered: {
            root.boot++;
            if (root.boot >= 5)
                stop();
        }
    }

    Process {
        id: fortuneProc

        command: ["sh", "-c", "command -v fortune >/dev/null && fortune -s -n 90 || echo 'install fortune-mod for fortunes'"]
        stdout: StdioCollector {
            onStreamFinished: root.fortune = text.trim().replace(/\s+/g, " ")
        }
    }


    property string armed: "" // power action waiting for a second click

    function power(action: string, cmd: list<string>): void {
        if (action === "lock" || action === "sleep" || armed === action) {
            armed = "";
            Panels.close();
            if (action === "lock")
                Panels.lock(false);
            else if (action === "sleep")
                Panels.suspend(); // locks first: never wake up to an open desktop
            else if (action === "logout")
                Hypr.exit();
            else
                Quickshell.execDetached(cmd);
        } else {
            armed = action;
            disarm.restart();
        }
    }


    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    Tabs {
        id: tabs

        tabs: ["sys", "top", "todo", "notes", "cfg"]
    }

    // the process list is only sampled while its tab is on screen
    Binding {
        target: SysInfo
        property: "topActive"
        value: tabs.current === 1
        when: root.open
    }

    // Every tab is in a Loader: only the shown one exists. With all five made at once (and
    // hidden), opening the profile built the todo list, the notes, the cfg and the process
    // list every time, and the cfg tab alone pulled in the whole ai service.

    // ---------------------------------------------------------------- sys
    //  ascii face / machine   user@host
    //                         arch · tp T480 · hyprland 0.55
    //                         up 3h 12m · sat 04.10 · 14:32
    //                         > stay curious
    //  ┌─cpu────── 42%┐ ┌─mem────── 61%┐ ┌─today──── 2 open┐
    //  │ ▁▂▅▇▆▃▂▁▂▅▇ │ │ ▃▃▄▄▅▅▅▆▆▆▆ │ │ 14:30 call mom    │
    //  └─────────────┘ └──────────────┘ └──────────────────┘
    //  net ↓1.2M ↑34K · disk 61% · bat 72% 3h left
    Loader {
        Layout.fillWidth: true
        active: tabs.current === 0
        visible: active

        sourceComponent: Component {
            SysTab {
                profile: root
            }
        }
    }

    // ---------------------------------------------------------------- top
    Loader {
        Layout.fillWidth: true
        active: tabs.current === 1
        visible: active

        sourceComponent: Component {
            TopTab {
                profile: root
            }
        }
    }


    // --------------------------------------------------------------- todo
    //  folders        │ + 2pm call mom #family !!█
    //  > inbox     3  │ !!  2:00 pm  call mom
    //    work      2  │ ·            buy milk
    //    all       5  │   ┌ note ────────────────────────┐
    //  + folder       │   │ take the blue bag            │
    //                 │   └──────────────────────────────┘
    //                 │   icon  · ! !! !!!  inbox work  [delete]
    Loader {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        active: tabs.current === 2
        visible: active

        sourceComponent: Component {
            TodoTab {
                profile: root
            }
        }
    }

    // -------------------------------------------------------------- notes
    //  folders        │ / search█                      [+ new]
    //  > notes     4  │ > shopping list         04.10 14:30
    //    ideas     2  │   kawt ideas            03.10 09:12   x
    //    all       6  │ ┌─────────────────────────────────────┐
    //  + folder       │ │ shopping list                        │
    //                 │ │ - milk█                              │
    //                 │ └─────────────────────────────────────┘
    //                 │  notes ideas                 [delete]
    Loader {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        active: tabs.current === 3
        visible: active

        sourceComponent: Component {
            NotesTab {
                profile: root
            }
        }
    }

    // ---------------------------------------------------------------- cfg
    Loader {
        Layout.fillWidth: true
        active: tabs.current === 4
        visible: active

        sourceComponent: Component {
            CfgTab {
                profile: root
            }
        }
    }
}
