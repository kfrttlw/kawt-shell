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
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
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
    //  + 14:30 call mom█
    //  [ ] 14:30           call mom
    //  [ ] tomorrow 09:00  dentist
    //  [x]                 buy milk
    ColumnLayout {
        Layout.fillWidth: true
        visible: tabs.current === 2
        spacing: 2

        TermInput {
            id: todoInput

            property string feedback: ""

            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            prompt: "+"
            placeholder: "14:30 call mom · 9am gym · +30m tea · 05.10 10:00 dentist"
            onAccepted: t => {
                todoInput.feedback = Todo.add(t);
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
            Layout.alignment: Qt.AlignRight
            text: todoInput.feedback
            visible: text !== ""
            color: Colors.accent
            font.pixelSize: Metrics.fontSize - 2
        }

        Label {
            visible: Todo.tasks.length === 0
            Layout.topMargin: Metrics.spacing
            text: "-- nothing to do --"
            color: Colors.dim
        }

        Flickable {
            id: todoFlick

            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            Layout.preferredHeight: Math.min(260, todoList.implicitHeight)
            visible: Todo.tasks.length > 0
            clip: true
            contentHeight: todoList.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: todoList

                width: todoFlick.width

                Repeater {
                    model: Todo.sorted

                    Item {
                        id: task

                        required property var modelData
                        readonly property bool overdue: !modelData.done && modelData.due > 0 && modelData.due < Time.now.getTime()

                        width: todoList.width
                        implicitHeight: taskRow.implicitHeight + 4

                        Rectangle {
                            anchors.fill: parent
                            visible: taskArea.containsMouse
                            color: Colors.hoverFill
                        }

                        RowLayout {
                            id: taskRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 2
                            anchors.rightMargin: 2
                            spacing: Metrics.spacing

                            Label {
                                text: task.modelData.done ? "[x]" : "[ ]"
                                color: task.modelData.done ? Colors.dim : Colors.accent
                            }

                            Label {
                                Layout.preferredWidth: Metrics.fontSize * 0.6 * 14
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

                            Label {
                                visible: taskArea.containsMouse
                                text: "x"
                                color: Colors.warn
                            }
                        }

                        // click: done / not done; click on the x (right edge) or right click: delete
                        MouseArea {
                            id: taskArea

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton || mouse.x > width - 20)
                                    Todo.remove(task.modelData.id);
                                else
                                    Todo.toggle(task.modelData.id);
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            visible: Todo.tasks.length > 0

            Label {
                Layout.fillWidth: true
                text: `-- ${Todo.open} open · reminders go to [log] --`
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 3
            }

            BracketButton {
                visible: Todo.open < Todo.tasks.length
                label: "clear done"
                bordered: false
                onClicked: Todo.clearDone()
            }
        }
    }

    // -------------------------------------------------------------- notes
    ColumnLayout {
        Layout.fillWidth: true
        visible: tabs.current === 3
        spacing: 2

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            implicitHeight: 240
            color: Colors.hoverFill
            border.color: notes.activeFocus ? Colors.dim : Colors.border
            border.width: Metrics.borderWidth

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.margins: Metrics.spacing
                clip: true
                contentHeight: notes.contentHeight
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: notes

                    width: flick.width
                    color: Colors.fg
                    font.family: Metrics.fontFamily
                    font.pixelSize: Metrics.fontSize
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.bg
                    cursorDelegate: BlockCursor {
                        visible: notes.activeFocus
                    }

                    Component.onCompleted: text = Notes.text
                    onTextChanged: Notes.set(text)
                    // keep the cursor in view while typing
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < flick.contentY)
                            flick.contentY = cursorRectangle.y;
                        else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                            flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
                    }

                    Label {
                        visible: !notes.text && !notes.activeFocus
                        text: "# todo\n- ..."
                        color: Colors.dim
                    }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignRight
            text: `-- ${notes.lineCount} lines · ~/.local/state/kawt/notes.txt --`
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
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
            text: "screenshots  (print · super+shift+s area · shift+print screen · alt+print window)"
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
            wrapMode: Text.Wrap
            text: "[?] hyprland binds: see hypr/kawt.lua in the config folder\n[?] in the ai panel: /model <name>, /models"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }
}
