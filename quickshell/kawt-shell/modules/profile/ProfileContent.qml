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
// Used by the small popover under [~] and by the full-screen dashboard (super + i).
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
    // notes tab: folder, opened note, the filtered list
    property string notesFolder: "notes"
    property real noteOpen: 0
    property bool noteLoaded: false
    readonly property var notesList: Notes.inFolder(notesFolder, noteSearch.text)

    // open a note in the editor (0 = close). Saves the one being left first.
    function openNote(id: real): void {
        if (noteSave.running) {
            noteSave.stop();
            Notes.update(noteOpen, { body: noteEdit.text });
        }
        noteLoaded = false;
        noteOpen = id;
        noteEdit.text = Notes.notes.find(n => n.id === id)?.body ?? "";
        noteLoaded = true;
        if (id)
            noteEdit.forceActiveFocus();
    }

    // 25m / 2h 10m / 3d
    function until(ms: real): string {
        const m = Math.max(0, Math.round((ms - Time.now.getTime()) / 60000));
        if (m < 60)
            return `${m}m`;
        if (m < 1440)
            return `${Math.floor(m / 60)}h${m % 60 ? ` ${m % 60}m` : ""}`;
        return `${Math.floor(m / 1440)}d`;
    }

    onOpenChanged: {
        armed = "";
        if (open) {
            boot = 0;
            bootTimer.restart();
            if (Settings.motto === "fortune")
                fortuneProc.running = true;
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

    // a titled box for the sys tab: ┌─cpu───── 42%┐
    component Card: TitledBox {
        id: card

        property bool warn: false
        default property alias content: cardBody.data

        Layout.fillWidth: true
        Layout.preferredWidth: 1 // equal widths
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: titleOverhang
        implicitHeight: cardBody.implicitHeight + Metrics.padding * 2 + titleOverhang
        border.color: warn ? Colors.warn : Colors.border

        ColumnLayout {
            id: cardBody

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + card.titleOverhang
            spacing: 4
        }
    }

    property string armed: "" // power action waiting for a second click

    function power(action: string, cmd: list<string>): void {
        if (action === "lock" || action === "sleep" || armed === action) {
            armed = "";
            Panels.close();
            if (action === "lock")
                Panels.locked = true;
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

    // ---------------------------------------------------------------- sys
    //  ascii face / machine   user@host
    //                         arch · tp T480 · hyprland 0.55
    //                         up 3h 12m · sat 04.10 · 14:32
    //                         > stay curious
    //  ┌─cpu────── 42%┐ ┌─mem────── 61%┐ ┌─today──── 2 open┐
    //  │ ▁▂▅▇▆▃▂▁▂▅▇ │ │ ▃▃▄▄▅▅▅▆▆▆▆ │ │ 14:30 call mom    │
    //  └─────────────┘ └──────────────┘ └──────────────────┘
    //  net ↓1.2M ↑34K · disk 61% · bat 72% 3h left
    ColumnLayout {
        Layout.fillWidth: true
        visible: tabs.current === 0
        spacing: Metrics.spacing

        // header
        RowLayout {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            spacing: Metrics.padding * 2
            opacity: root.boot > 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }

            AsciiAvatar {
                id: avatar

                Layout.alignment: Qt.AlignTop
                visible: Settings.profileArt === "auto" && available
                cols: root.wide ? 30 : 22
            }

            DeviceArt {
                Layout.alignment: Qt.AlignTop
                visible: !avatar.visible
                laptop: SysInfo.laptop
                blink: root.open
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: `${SysInfo.user}@${SysInfo.host}`
                    color: Colors.accent
                    font.pixelSize: Math.round(Metrics.fontSize * 1.6)
                    font.bold: true
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: [SysInfo.os.toLowerCase(), SysInfo.model.replace(/^ThinkPad /, "tp "), SysInfo.wm].filter(s => s).join(" · ")
                    color: Colors.dim
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: `up ${Fmt.uptime(SysInfo.uptime)} · ${Qt.formatDate(Time.now, "ddd dd.MM").toLowerCase()} · ${Time.fmt(Time.now)}`
                    color: Colors.dim
                }

                // the motto: a line of your own, or a fortune each time the profile opens
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacing
                    visible: text !== ""
                    elide: Text.ElideRight
                    text: Settings.motto === "" ? "" : `> ${Settings.motto === "fortune" ? root.fortune : Settings.motto}`
                    color: Colors.fg
                }
            }
        }

        // cards
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            spacing: Metrics.spacing
            opacity: root.boot > 1 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }

            Card {
                title: "cpu"
                hint: `${Math.round(SysInfo.cpu * 100)}%`
                warn: SysInfo.cpuTemp >= 85

                BarGraph {
                    Layout.fillWidth: true
                    values: SysInfo.cpuHistory.slice(root.wide ? -40 : -24)
                    barColor: SysInfo.cpuTemp >= 85 ? Colors.warn : Colors.accent
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: [SysInfo.cpuTemp >= 0 ? `${Math.round(SysInfo.cpuTemp)}°C` : "", SysInfo.fan > 0 ? `${SysInfo.fan} rpm` : SysInfo.fan === 0 ? "fan idle" : "", SysInfo.load ? `load ${SysInfo.load.split(" ")[0]}` : ""].filter(s => s).join(" · ")
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }
            }

            Card {
                title: "mem"
                hint: `${Math.round(SysInfo.mem * 100)}%`

                BarGraph {
                    Layout.fillWidth: true
                    values: SysInfo.memHistory.slice(root.wide ? -40 : -24)
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: `${SysInfo.memUsedGb.toFixed(1)}/${SysInfo.memTotalGb.toFixed(0)}G` + (SysInfo.swapTotalGb > 0 ? ` · swap ${(SysInfo.swap * SysInfo.swapTotalGb).toFixed(1)}G` : "")
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }
            }

            Card {
                title: "today"
                hint: Todo.open > 0 ? `${Todo.open} open` : ""

                Label {
                    visible: root.upcoming.length === 0
                    text: "-- free day --"
                    color: Colors.dim
                }

                Repeater {
                    model: root.upcoming.slice(0, 3)

                    Label {
                        required property var modelData

                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: `${modelData.due ? Time.fmt(new Date(modelData.due)) : "  -  "}  ${modelData.text}`
                        color: modelData.due && modelData.due < Time.now.getTime() ? Colors.warn : Colors.fg
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: root.next !== null
                    elide: Text.ElideRight
                    text: root.next ? `next in ${root.until(root.next.due)}` : ""
                    color: Colors.accent
                    font.pixelSize: Metrics.fontSize - 2
                }
            }
        }

        // one status line
        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            opacity: root.boot > 2 ? 1 : 0
            text: {
                const dev = UPower.displayDevice;
                const plugged = dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged;
                return [
                    `net ↓${Fmt.rate(NetStats.rx).trim()} ↑${Fmt.rate(NetStats.tx).trim()}`,
                    `disk ${Math.round(SysInfo.disk * 100)}%`,
                    dev.isLaptopBattery ? `bat ${Math.round(dev.percentage * 100)}%${plugged ? "+" : ""}` + (!plugged && dev.timeToEmpty > 0 ? ` ${Fmt.uptime(dev.timeToEmpty)} left` : "") : "",
                    SysInfo.pkgs > 0 ? `${SysInfo.pkgs} pkgs` : ""
                ].filter(s => s).join(" · ");
            }
            color: Colors.dim

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }
        }

        // the rest of the neofetch facts, small
        Flow {
            Layout.fillWidth: true
            spacing: Metrics.padding
            opacity: root.boot > 3 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }

            Repeater {
                model: [
                    ["cpu", SysInfo.cpuModel + (SysInfo.cores > 0 ? ` (${SysInfo.cores})` : "")],
                    ...SysInfo.gpus.map(g => ["gpu", g]),
                    ["kern", SysInfo.kernel],
                    ["shell", SysInfo.shell],
                    ["res", SysInfo.res]
                ].filter(r => r[1])

                Row {
                    required property var modelData

                    spacing: 4

                    Label {
                        text: modelData[0]
                        color: Colors.dim
                        font.pixelSize: Metrics.fontSize - 2
                    }

                    Label {
                        text: modelData[1]
                        font.pixelSize: Metrics.fontSize - 2
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            implicitHeight: Metrics.borderWidth
            color: Colors.border
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            opacity: root.boot > 4 ? 1 : 0
            spacing: Metrics.spacing

            BracketButton {
                label: "lock"
                onClicked: root.power("lock", [])
            }

            BracketButton {
                label: "sleep"
                onClicked: root.power("sleep", ["systemctl", "suspend"])
            }

            BracketButton {
                label: root.armed === "logout" ? "sure?" : "logout"
                textColor: root.armed === "logout" ? Colors.warn : Colors.fg
                onClicked: root.power("logout", [])
            }

            BracketButton {
                label: root.armed === "reboot" ? "sure?" : "reboot"
                textColor: root.armed === "reboot" ? Colors.warn : Colors.fg
                onClicked: root.power("reboot", ["systemctl", "reboot"])
            }

            BracketButton {
                label: root.armed === "off" ? "sure?" : "off"
                textColor: root.armed === "off" ? Colors.warn : Colors.fg
                onClicked: root.power("off", ["systemctl", "poweroff"])
            }
        }
    }

    // ---------------------------------------------------------------- top
    ColumnLayout {
        Layout.fillWidth: true
        visible: tabs.current === 1
        spacing: 0

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.bottomMargin: Metrics.spacing
            text: `tasks ${SysInfo.taskCount} · cpu ${Math.round(SysInfo.cpu * 100)}% · load ${SysInfo.load}`
            color: Colors.dim
        }

        Label {
            text: "    PID  CPU%  MEM%  S  COMMAND"
            color: Colors.accent
        }

        Repeater {
            model: SysInfo.procs

            Item {
                id: proc

                required property var modelData
                readonly property bool armed: root.armed === `kill:${modelData.pid}`

                Layout.fillWidth: true
                implicitHeight: procLine.implicitHeight

                Rectangle {
                    anchors.fill: parent
                    visible: procArea.containsMouse || proc.armed
                    color: Colors.hoverFill
                }

                Label {
                    id: procLine

                    width: parent.width
                    elide: Text.ElideRight
                    text: proc.armed
                        ? `${String(proc.modelData.pid).padStart(7)}  kill ${proc.modelData.comm}? click again`
                        : `${String(proc.modelData.pid).padStart(7)} ${proc.modelData.cpu.toFixed(1).padStart(5)} ${proc.modelData.mem.toFixed(1).padStart(5)}  ${proc.modelData.state}  ${proc.modelData.comm}`
                    color: proc.armed ? Colors.warn : proc.modelData.cpu >= 50 ? Colors.accent : Colors.fg
                }

                MouseArea {
                    id: procArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (proc.armed) {
                            root.armed = "";
                            SysInfo.kill(proc.modelData.pid);
                        } else {
                            root.armed = `kill:${proc.modelData.pid}`;
                            disarm.restart();
                        }
                    }
                }
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.alignment: Qt.AlignRight
            text: "click twice: kill (SIGTERM)"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
        }
    }

    // cpu [########------------]  42%  54°C  ▁▂▃▅▇▆▃▂
    component Meter: RowLayout {
        id: meter

        property string name
        property real value
        property string suffix
        property string extra
        property var history: []
        property bool warn: false

        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            text: `${meter.name} [${Fmt.bar(meter.value, 20)}] ${String(Math.round(meter.value * 100)).padStart(3)}%${meter.suffix}`
            color: meter.warn ? Colors.warn : Colors.fg
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: meter.extra
            color: Colors.dim
        }

        Label {
            visible: meter.history.length > 0
            text: Fmt.spark(meter.history.slice(-16))
            color: Colors.accent
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
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: tabs.current === 2
        spacing: Metrics.padding

        // folders
        ColumnLayout {
            Layout.preferredWidth: root.wide ? 190 : 140
            Layout.maximumWidth: root.wide ? 190 : 140
            Layout.alignment: Qt.AlignTop
            spacing: 0

            Label {
                text: "folders"
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }

            Repeater {
                model: [...Todo.folders, "all"]

                Item {
                    id: folderRow

                    required property string modelData
                    readonly property bool current: root.todoFolder === modelData

                    Layout.fillWidth: true
                    implicitHeight: folderLabel.implicitHeight + 4

                    Rectangle {
                        anchors.fill: parent
                        visible: folderRow.current || folderArea.containsMouse
                        color: Colors.hoverFill
                    }

                    Label {
                        id: folderLabel

                        anchors.left: parent.left
                        anchors.right: folderCount.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: (folderRow.current ? "> " : "  ") + folderRow.modelData
                        color: folderRow.current ? Colors.accent : Colors.fg
                    }

                    Label {
                        id: folderCount

                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        // hovering a removable folder shows its x
                        text: folderArea.containsMouse && folderRow.modelData !== "inbox" && folderRow.modelData !== "all" ? "x" : String(Todo.openIn(folderRow.modelData) || "")
                        color: folderArea.containsMouse && text === "x" ? Colors.warn : Colors.dim
                    }

                    MouseArea {
                        id: folderArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (folderCount.text === "x" && mouse.x > width - 20) {
                                if (root.todoFolder === folderRow.modelData)
                                    root.todoFolder = "inbox";
                                Todo.removeFolder(folderRow.modelData);
                            } else {
                                root.todoFolder = folderRow.modelData;
                            }
                        }
                    }
                }
            }

            TermInput {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                prompt: "+"
                placeholder: "folder"
                onAccepted: t => {
                    Todo.addFolder(t);
                    root.todoFolder = t.trim().toLowerCase().replace(/\s+/g, "-") || root.todoFolder;
                    text = "";
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: Metrics.borderWidth
            color: Colors.border
        }

        // tasks of the folder
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.alignment: Qt.AlignTop
            spacing: 2

            TermInput {
                id: todoInput

                property string feedback: ""

                Layout.fillWidth: true
                prompt: "+"
                placeholder: "2pm call mom #family !!"
                onAccepted: t => {
                    todoInput.feedback = Todo.add(t, root.todoFolder);
                    todoInput.text = "";
                    feedbackTimer.restart();
                }

                Timer {
                    id: feedbackTimer

                    interval: 3000
                    onTriggered: todoInput.feedback = ""
                }
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: todoInput.feedback || "time first: 14:30 · 9am · +30m · 05.10 10:00   tags: #folder  ! !! !!!"
                color: todoInput.feedback ? Colors.accent : Colors.dim
                font.pixelSize: Metrics.fontSize - 3
            }

            Label {
                visible: root.todoTasks.length === 0
                Layout.topMargin: Metrics.spacing
                text: "-- nothing here --"
                color: Colors.dim
            }

            Flickable {
                id: todoFlick

                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                Layout.preferredHeight: Math.min(root.wide ? 460 : 320, todoList.implicitHeight)
                visible: root.todoTasks.length > 0
                clip: true
                contentHeight: todoList.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: todoList

                    width: todoFlick.width
                    spacing: 1

                    Repeater {
                        model: root.todoTasks

                        Column {
                            id: task

                            required property var modelData
                            readonly property bool expanded: root.todoOpen === modelData.id
                            readonly property bool overdue: !modelData.done && modelData.due > 0 && modelData.due < Time.now.getTime()

                            width: todoList.width

                            // ---- the task line: [ ] icon !!  2:00 pm  text            note x
                            Item {
                                width: parent.width
                                implicitHeight: taskRow.implicitHeight + 6

                                Rectangle {
                                    anchors.fill: parent
                                    visible: taskArea.containsMouse || task.expanded
                                    color: Colors.hoverFill
                                }

                                RowLayout {
                                    id: taskRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 2
                                    anchors.rightMargin: 4
                                    spacing: Metrics.spacing

                                    Label {
                                        text: task.modelData.done ? "[x]" : "[ ]"
                                        color: task.modelData.done ? Colors.dim : Colors.accent
                                    }

                                    Label {
                                        Layout.preferredWidth: Metrics.fontSize
                                        text: task.modelData.icon
                                        color: task.modelData.done ? Colors.dim : Colors.fg
                                    }

                                    Label {
                                        Layout.preferredWidth: Metrics.fontSize * 0.6 * 3
                                        text: "!".repeat(task.modelData.prio)
                                        color: task.modelData.done ? Colors.dim : task.modelData.prio >= 3 ? Colors.warn : Colors.accent
                                        font.bold: true
                                    }

                                    Label {
                                        visible: task.modelData.due > 0
                                        text: task.modelData.due ? Todo.when(task.modelData.due) : ""
                                        color: task.overdue ? Colors.warn : Colors.dim
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: task.modelData.text
                                        color: task.modelData.done ? Colors.dim : Colors.fg
                                        font.strikeout: task.modelData.done
                                    }

                                    // a note is inside
                                    Label {
                                        visible: task.modelData.note !== ""
                                        text: ""
                                        color: Colors.dim
                                    }

                                    Label {
                                        visible: root.todoFolder === "all"
                                        text: task.modelData.folder
                                        color: Colors.dim
                                        font.pixelSize: Metrics.fontSize - 2
                                    }
                                }

                                // the box toggles done; anywhere else opens the task
                                MouseArea {
                                    id: taskArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.x < Metrics.fontSize * 2.4)
                                            Todo.toggle(task.modelData.id);
                                        else
                                            root.todoOpen = task.expanded ? 0 : task.modelData.id;
                                    }
                                }
                            }

                            // ---- opened: note, icon, importance, folder, delete
                            ColumnLayout {
                                visible: task.expanded
                                x: Metrics.fontSize * 2
                                width: parent.width - x - 4
                                spacing: Metrics.spacing

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    implicitHeight: Math.max(60, note.contentHeight + 12)
                                    color: Colors.bg
                                    border.color: note.activeFocus ? Colors.dim : Colors.border
                                    border.width: Metrics.borderWidth

                                    TextEdit {
                                        id: note

                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: task.modelData.note
                                        color: Colors.fg
                                        font.family: Metrics.fontFamily
                                        font.pixelSize: Metrics.fontSize - 1
                                        wrapMode: TextEdit.Wrap
                                        selectByMouse: true
                                        selectionColor: Colors.accent
                                        selectedTextColor: Colors.bg
                                        cursorDelegate: BlockCursor {
                                            visible: note.activeFocus
                                        }
                                        // saved when you click away: saving on every key would
                                        // rebuild the list under the cursor
                                        onActiveFocusChanged: if (!activeFocus && text !== task.modelData.note)
                                            Todo.update(task.modelData.id, { note: text })

                                        Label {
                                            visible: !note.text && !note.activeFocus
                                            text: "note..."
                                            color: Colors.dim
                                            font.pixelSize: Metrics.fontSize - 1
                                        }
                                    }
                                }

                                // icon
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Repeater {
                                        model: Todo.icons

                                        BracketButton {
                                            required property string modelData

                                            label: modelData || " "
                                            bordered: false
                                            active: task.modelData.icon === modelData
                                            textColor: task.modelData.icon === modelData ? Colors.accent : Colors.dim
                                            onClicked: Todo.update(task.modelData.id, { icon: modelData })
                                        }
                                    }
                                }

                                // importance · folder · delete
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Metrics.spacing

                                    Repeater {
                                        model: ["·", "!", "!!", "!!!"]

                                        BracketButton {
                                            required property string modelData
                                            required property int index

                                            label: modelData
                                            active: task.modelData.prio === index
                                            textColor: task.modelData.prio === index ? (index >= 3 ? Colors.warn : Colors.accent) : Colors.dim
                                            onClicked: Todo.update(task.modelData.id, { prio: index })
                                        }
                                    }

                                    Label {
                                        text: " "
                                    }

                                    Repeater {
                                        model: Todo.folders

                                        BracketButton {
                                            required property string modelData

                                            label: modelData
                                            bordered: false
                                            active: task.modelData.folder === modelData
                                            textColor: task.modelData.folder === modelData ? Colors.accent : Colors.dim
                                            onClicked: Todo.update(task.modelData.id, { folder: modelData })
                                        }
                                    }

                                    BracketButton {
                                        label: "delete"
                                        textColor: Colors.warn
                                        bordered: false
                                        onClicked: {
                                            root.todoOpen = 0;
                                            Todo.remove(task.modelData.id);
                                        }
                                    }
                                }

                                Item {
                                    implicitHeight: 4
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                visible: root.todoTasks.length > 0

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: `-- ${Todo.openIn(root.todoFolder)} open · click a task to open it · reminders go to [log] --`
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 3
                }

                BracketButton {
                    visible: root.todoTasks.some(t => t.done)
                    label: "clear done"
                    bordered: false
                    onClicked: Todo.clearDone(root.todoFolder)
                }
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
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: tabs.current === 3
        spacing: Metrics.padding

        // folders
        ColumnLayout {
            Layout.preferredWidth: root.wide ? 190 : 140
            Layout.maximumWidth: root.wide ? 190 : 140
            Layout.alignment: Qt.AlignTop
            spacing: 0

            Label {
                text: "folders"
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }

            Repeater {
                model: [...Notes.folders, "all"]

                Item {
                    id: nfRow

                    required property string modelData
                    readonly property bool current: root.notesFolder === modelData
                    readonly property bool removable: modelData !== "notes" && modelData !== "all"

                    Layout.fillWidth: true
                    implicitHeight: nfLabel.implicitHeight + 4

                    Rectangle {
                        anchors.fill: parent
                        visible: nfRow.current || nfArea.containsMouse
                        color: Colors.hoverFill
                    }

                    Label {
                        id: nfLabel

                        anchors.left: parent.left
                        anchors.right: nfCount.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: (nfRow.current ? "> " : "  ") + nfRow.modelData
                        color: nfRow.current ? Colors.accent : Colors.fg
                    }

                    Label {
                        id: nfCount

                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: nfArea.containsMouse && nfRow.removable ? "x" : String(Notes.count(nfRow.modelData) || "")
                        color: text === "x" ? Colors.warn : Colors.dim
                    }

                    MouseArea {
                        id: nfArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (nfRow.removable && mouse.x > width - 20) {
                                if (root.notesFolder === nfRow.modelData)
                                    root.notesFolder = "notes";
                                Notes.removeFolder(nfRow.modelData);
                            } else {
                                root.notesFolder = nfRow.modelData;
                            }
                        }
                    }
                }
            }

            TermInput {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                prompt: "+"
                placeholder: "folder"
                onAccepted: t => {
                    const name = Notes.addFolder(t);
                    if (name)
                        root.notesFolder = name;
                    text = "";
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: Metrics.borderWidth
            color: Colors.border
        }

        // list + editor
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.alignment: Qt.AlignTop
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                TermInput {
                    id: noteSearch

                    Layout.fillWidth: true
                    prompt: "/"
                    placeholder: "search"
                }

                BracketButton {
                    label: "+ new"
                    textColor: Colors.accent
                    onClicked: root.openNote(Notes.create(root.notesFolder))
                }
            }

            Label {
                visible: root.notesList.length === 0
                Layout.topMargin: Metrics.spacing
                text: noteSearch.text ? "-- nothing found --" : "-- no notes here: [+ new] --"
                color: Colors.dim
            }

            // the list: title · date · x
            Flickable {
                id: notesFlick

                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                Layout.preferredHeight: Math.min(root.wide ? 200 : 132, notesListCol.implicitHeight)
                visible: root.notesList.length > 0
                clip: true
                contentHeight: notesListCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: notesListCol

                    width: notesFlick.width

                    Repeater {
                        model: root.notesList

                        Item {
                            id: noteRow

                            required property var modelData
                            readonly property bool current: root.noteOpen === modelData.id

                            width: notesListCol.width
                            implicitHeight: noteTitle.implicitHeight + 6

                            Rectangle {
                                anchors.fill: parent
                                visible: noteRow.current || noteArea.containsMouse
                                color: Colors.hoverFill
                            }

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 2
                                anchors.rightMargin: 4
                                spacing: Metrics.spacing

                                Label {
                                    id: noteTitle

                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: (noteRow.current ? "> " : "  ") + Notes.title(noteRow.modelData)
                                    color: noteRow.current ? Colors.accent : Colors.fg
                                }

                                Label {
                                    visible: root.notesFolder === "all"
                                    text: noteRow.modelData.folder
                                    color: Colors.dim
                                    font.pixelSize: Metrics.fontSize - 2
                                }

                                Label {
                                    text: Qt.formatDateTime(new Date(noteRow.modelData.updated), "dd.MM hh:mm")
                                    color: Colors.dim
                                    font.pixelSize: Metrics.fontSize - 2
                                }

                                Label {
                                    text: "x"
                                    opacity: noteArea.containsMouse ? 1 : 0
                                    color: Colors.warn
                                }
                            }

                            // click: open · the x on the right: delete
                            MouseArea {
                                id: noteArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.x > width - 20) {
                                        if (root.noteOpen === noteRow.modelData.id)
                                            root.openNote(0);
                                        Notes.remove(noteRow.modelData.id);
                                    } else {
                                        root.openNote(noteRow.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // the editor of the opened note
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                visible: root.noteOpen !== 0
                implicitHeight: root.wide ? 300 : 220
                color: Colors.bg
                border.color: noteEdit.activeFocus ? Colors.dim : Colors.border
                border.width: Metrics.borderWidth

                Flickable {
                    id: noteFlick

                    anchors.fill: parent
                    anchors.margins: Metrics.spacing
                    clip: true
                    contentHeight: noteEdit.contentHeight
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: noteEdit

                        width: noteFlick.width
                        color: Colors.fg
                        font.family: Metrics.fontFamily
                        font.pixelSize: Metrics.fontSize
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        selectionColor: Colors.accent
                        selectedTextColor: Colors.bg
                        cursorDelegate: BlockCursor {
                            visible: noteEdit.activeFocus
                        }

                        // the text is set only when a note is opened (root.openNote), never bound:
                        // a binding would jump the cursor on every save
                        onTextChanged: if (root.noteLoaded)
                            noteSave.restart()

                        // keep the cursor in view while typing
                        onCursorRectangleChanged: {
                            if (cursorRectangle.y < noteFlick.contentY)
                                noteFlick.contentY = cursorRectangle.y;
                            else if (cursorRectangle.y + cursorRectangle.height > noteFlick.contentY + noteFlick.height)
                                noteFlick.contentY = cursorRectangle.y + cursorRectangle.height - noteFlick.height;
                        }

                        Label {
                            visible: !noteEdit.text && !noteEdit.activeFocus
                            text: "first line = title\n..."
                            color: Colors.dim
                        }
                    }
                }

                Timer {
                    id: noteSave

                    interval: 500
                    onTriggered: Notes.update(root.noteOpen, { body: noteEdit.text })
                }
            }

            // move to a folder · delete
            Flow {
                Layout.fillWidth: true
                visible: root.noteOpen !== 0
                spacing: Metrics.spacing

                Repeater {
                    model: Notes.folders

                    BracketButton {
                        required property string modelData
                        readonly property var note: Notes.notes.find(n => n.id === root.noteOpen)

                        label: modelData
                        bordered: false
                        active: note?.folder === modelData
                        textColor: note?.folder === modelData ? Colors.accent : Colors.dim
                        onClicked: Notes.update(root.noteOpen, { folder: modelData })
                    }
                }

                BracketButton {
                    label: "delete"
                    textColor: Colors.warn
                    bordered: false
                    onClicked: {
                        const id = root.noteOpen;
                        root.openNote(0);
                        Notes.remove(id);
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignRight
                text: `-- ${Notes.count("all")} notes · ~/.local/state/kawt/notes.json --`
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 3
            }
        }
    }

    // ---------------------------------------------------------------- cfg
    ColumnLayout {
        Layout.fillWidth: true
        visible: tabs.current === 4
        spacing: Metrics.spacing
        onVisibleChanged: if (visible)
            Ai.checkStatus()

        RowLayout {
            Layout.topMargin: Metrics.spacing
            spacing: Metrics.spacing

            Label {
                text: `theme: ${Colors.fullName}`
                color: Colors.dim
            }

            BracketButton {
                label: "wallpaper & themes"
                textColor: Colors.accent
                onClicked: Panels.toggle("style", root.forScreen)
            }
        }

        // ------------------------------------------------------------ clock
        //  clock  [24h] 12h  [x] seconds  [ ] date
        //  time>  14:30 / +3h / -30m   [real time]
        Label {
            Layout.topMargin: Metrics.spacing
            text: "clock"
            color: Colors.dim
        }

        Flow {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            BracketButton {
                label: "24h"
                active: Settings.clock24
                textColor: Settings.clock24 ? Colors.accent : Colors.dim
                onClicked: Settings.clock24 = true
            }

            BracketButton {
                label: "12h"
                active: !Settings.clock24
                textColor: !Settings.clock24 ? Colors.accent : Colors.dim
                onClicked: Settings.clock24 = false
            }

            BracketButton {
                tag: Settings.clockSeconds ? "x" : " "
                label: "seconds"
                bordered: false
                onClicked: Settings.clockSeconds = !Settings.clockSeconds
            }

            BracketButton {
                tag: Settings.clockDate ? "x" : " "
                label: "date"
                bordered: false
                onClicked: Settings.clockDate = !Settings.clockDate
            }
        }

        // shell-only time: the system clock is never touched
        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            TermInput {
                id: clockInput

                property string error: ""

                Layout.fillWidth: true
                prompt: "time>"
                placeholder: "14:30 · 2:30pm · +3h · -30m  (only kawt's clock)"
                onAccepted: t => {
                    clockInput.error = Time.set(t);
                    if (!clockInput.error)
                        clockInput.text = "";
                }
            }

            BracketButton {
                visible: Time.offset !== 0
                label: "real time"
                onClicked: Time.reset()
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            elide: Text.ElideRight
            text: clockInput.error !== "" ? clockInput.error
                : Time.offset !== 0 ? `kawt runs ${Time.offsetText} from the system clock (todo reminders too)` : ""
            color: clockInput.error !== "" ? Colors.warn : Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        // ------------------------------------------------------------ profile header
        Label {
            Layout.topMargin: Metrics.spacing
            text: "profile"
            color: Colors.dim
        }

        TermInput {
            Layout.fillWidth: true
            prompt: "motto>"
            text: Settings.motto
            placeholder: "a line under your name · fortune · empty = none"
            onAccepted: t => Settings.motto = t.trim()
        }

        RowLayout {
            spacing: Metrics.spacing

            Label {
                text: "picture:"
                color: Colors.dim
            }

            BracketButton {
                label: "~/.face as ascii"
                active: Settings.profileArt === "auto"
                textColor: Settings.profileArt === "auto" ? Colors.accent : Colors.dim
                onClicked: Settings.profileArt = "auto"
            }

            BracketButton {
                label: "machine"
                active: Settings.profileArt === "machine"
                textColor: Settings.profileArt === "machine" ? Colors.accent : Colors.dim
                onClicked: Settings.profileArt = "machine"
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "screenshots  (print / super+shift+s: area · shift+print: screen · alt+print: window)"
            color: Colors.dim
        }

        TermInput {
            Layout.fillWidth: true
            prompt: "dir>"
            text: Settings.screenshotDir
            onAccepted: t => Settings.screenshotDir = t.trim() || Settings.screenshotDir
        }

        Label {
            Layout.topMargin: Metrics.spacing
            text: "bar"
            color: Colors.dim
        }

        // wifi button: [name] bars hidden
        RowLayout {
            spacing: Metrics.spacing

            Label {
                text: "wifi:"
                color: Colors.dim
            }

            Repeater {
                model: [["name", "name"], ["bars", "▂▄▆_"], ["hidden", "hidden (click the graph)"]]

                BracketButton {
                    required property var modelData

                    label: modelData[1]
                    active: Settings.wifiStyle === modelData[0]
                    textColor: Settings.wifiStyle === modelData[0] ? Colors.accent : Colors.dim
                    onClicked: Settings.wifiStyle = modelData[0]
                }
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            text: "device"
            color: Colors.dim
        }

        Flow {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Repeater {
                model: ["auto", "laptop", "desktop"]

                BracketButton {
                    required property string modelData

                    label: modelData === "auto" ? `auto: ${SysInfo.detectedLaptop ? "laptop" : "desktop"}` : modelData
                    active: Settings.device === modelData
                    onClicked: Settings.device = modelData
                }
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            text: Ai.online ? "ollama model" : "ollama model (offline)"
            color: Colors.dim
        }

        // pulled models
        Flow {
            Layout.fillWidth: true
            visible: Ai.models.length > 0
            spacing: Metrics.spacing

            Repeater {
                model: Ai.models

                BracketButton {
                    required property string modelData

                    label: modelData.replace(/:latest$/, "")
                    active: Settings.ollamaModel === modelData || Settings.ollamaModel + ":latest" === modelData
                    onClicked: Settings.ollamaModel = modelData
                }
            }
        }

        TermInput {
            Layout.fillWidth: true
            prompt: "$"
            text: Settings.ollamaModel
            onAccepted: t => Settings.ollamaModel = t.trim() || Settings.ollamaModel
        }

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "[?] hyprland binds: see hypr/kawt.lua in the config folder"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "[?] in the ai panel: /model <name>, /models"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }
}
