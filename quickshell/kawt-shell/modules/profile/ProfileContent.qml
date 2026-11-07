import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import "../popovers"

// What's inside kawt's two windows, by tabs: today (super + i) has today / todo / notes /
// focus, system has machine / processes / net / power (TodayWindow.qml, SystemWindow.qml).
// The tabs keep what they share here: the opened task and note, the power buttons' second click.
ColumnLayout {
    id: root

    property bool open: false
    property ShellScreen forScreen: null
    property bool wide: true // room for cards side by side
    // the tabs, by name: show("focus")
    property list<string> tabNames: ["today", "todo", "notes", "focus"]
    readonly property string shown: tabNames[tabs.current] ?? ""

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
            return Strings.t("inMin").arg(m);
        if (m < 1440)
            return m % 60 ? Strings.t("inHoursMin").arg(Math.floor(m / 60)).arg(m % 60) : Strings.t("inHours").arg(m / 60);
        return Strings.t("inDays").arg(Math.floor(m / 1440));
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

    function show(name: string): void {
        tabs.current = Math.max(0, tabNames.indexOf(name));
    }

    function openTask(task: var): void {
        todoFolder = task.folder ?? "inbox";
        todoOpen = task.id;
        show("todo");
    }

    Tabs {
        id: tabs

        tabs: root.tabNames.map(n => Strings.t(`tab_${n}`))
    }

    // the process list is only sampled while its tab is on screen
    Binding {
        target: SysInfo
        property: "topActive"
        value: root.shown === "top"
        when: root.open
    }

    // Every tab is in a Loader: only the shown one exists. With all of them made at once (and
    // hidden), opening the profile built the todo list, the notes, the cfg and the process list
    // every time, and the old cfg tab alone pulled in the whole ai service.
    component Page: Loader {
        required property string name

        Layout.fillWidth: true
        active: root.shown === name
        visible: active
    }

    Page {
        name: "today"

        sourceComponent: Component {
            TodayTab {
                profile: root
            }
        }
    }

    Page {
        name: "todo"
        Layout.topMargin: Metrics.spacing

        sourceComponent: Component {
            TodoTab {
                profile: root
            }
        }
    }

    Page {
        name: "notes"
        Layout.topMargin: Metrics.spacing

        sourceComponent: Component {
            NotesTab {
                profile: root
            }
        }
    }

    Page {
        name: "focus"

        sourceComponent: Component {
            FocusTab {
                profile: root
            }
        }
    }

    Page {
        name: "sys"

        sourceComponent: Component {
            SysTab {
                profile: root
                part: "main"
            }
        }
    }

    Page {
        name: "power"

        sourceComponent: Component {
            SysTab {
                profile: root
                part: "power"
            }
        }
    }

    // who's on the net: the wifi panel's second page, here with room
    Page {
        name: "net"
        Layout.topMargin: Metrics.spacing

        sourceComponent: Component {
            WhoOut {}
        }
    }

    Page {
        name: "top"

        sourceComponent: Component {
            TopTab {
                profile: root
            }
        }
    }
}
