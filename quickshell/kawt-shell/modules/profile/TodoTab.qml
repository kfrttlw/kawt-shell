import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// The todo tab:
//
//   folders        │ + 2pm call mom tomorrow #family !!█
//   > inbox     3  │ time first: 14:30 · +30m · 05.10 10:00   #folder  ! !! !!!  every day
//     work      2  │ [ ] !!  14:30  call mom                         in 58m
//     family    1  │ [ ] !   18:00  gym                              ↻ week
//     all       6  │ [ ]            kawt readme             ▮▮▯ 2/3
//   ─────────────  │     [x] new screenshots      (an opened task: its steps, note, how often,
//   done today  5  │     [ ] write it              icon, importance, folder)
//   streak     4d  │ [x]            reply to anna
//                  │ ───────────────────────────────────────────────────────
//                  │ j k move · x done · enter open · n new · r again · f focus
//
// A ticked task is struck through first, then slides down to the done ones; a new one fades in.
// Keys work while the list has the focus (a click on it; esc leaves the input for it)
RowLayout {
    id: tab

    required property var profile
    property int sel: -1 // the task picked with the keys (an index in profile.todoTasks)
    readonly property var tasks: profile.todoTasks
    readonly property var selTask: sel >= 0 && sel < tasks.length ? tasks[sel] : null

    spacing: Metrics.padding
    focus: true
    Component.onCompleted: forceActiveFocus()

    function move(by: int): void {
        if (tasks.length === 0)
            return;
        sel = Math.max(0, Math.min(tasks.length - 1, sel < 0 ? 0 : sel + by));
        // keep it in sight
        let item = null;
        for (const c of todoList.children)
            if (c.index === sel && c.modelData !== undefined)
                item = c;
        if (item) {
            if (item.y < todoFlick.contentY)
                todoFlick.contentY = item.y;
            else if (item.y + item.height > todoFlick.contentY + todoFlick.height)
                todoFlick.contentY = item.y + item.height - todoFlick.height;
        }
    }

    // ticking off is drawn first (struck through), the list moves a moment later. Another one
    // ticked meanwhile: the first goes through at once; the same one again: not ticked after all
    property real ticking: 0

    function tick(task: var): void {
        if (tickLater.running) {
            tickLater.stop();
            const was = ticking;
            ticking = 0;
            if (was === task.id)
                return;
            Todo.toggle(was);
        }
        if (task.done) {
            Todo.toggle(task.id);
            return;
        }
        ticking = task.id;
        tickLater.restart();
    }

    Timer {
        id: tickLater

        interval: 380
        onTriggered: {
            Todo.toggle(tab.ticking);
            tab.ticking = 0;
        }
    }

    // the menu closed (or another tab opened) within that moment: ticked all the same, once this
    // tab is gone (its list can't be rebuilt while it's being taken down)
    Component.onDestruction: if (tickLater.running)
        Qt.callLater(Todo.toggle, ticking)

    readonly property list<string> repeats: ["", "day", "weekdays", "week", "month"]

    Keys.onPressed: event => {
        const t = tab.selTask;
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down)
            tab.move(1);
        else if (event.key === Qt.Key_K || event.key === Qt.Key_Up)
            tab.move(-1);
        else if ((event.key === Qt.Key_X || event.key === Qt.Key_Space) && t)
            tab.tick(t);
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && t)
            tab.profile.todoOpen = tab.profile.todoOpen === t.id ? 0 : t.id;
        else if (event.key === Qt.Key_N || event.key === Qt.Key_Slash)
            todoInput.input.forceActiveFocus();
        else if (event.key === Qt.Key_R && t)
            Todo.setRepeat(t.id, tab.repeats[(tab.repeats.indexOf(t.repeat) + 1) % tab.repeats.length]);
        else if (event.key === Qt.Key_F && t && !t.done) {
            Focus.start(t.id);
            tab.profile.show("focus");
        } else
            return;
        event.accepted = true;
    }

    // ---- folders, and how the days go
    ColumnLayout {
        Layout.preferredWidth: tab.profile.wide ? 190 : 140
        Layout.maximumWidth: tab.profile.wide ? 190 : 140
        Layout.alignment: Qt.AlignTop
        spacing: 0

        Label {
            text: Strings.t("folders")
            color: Colors.dim
        }

        FolderList {
            Layout.topMargin: 4
            folders: [...Todo.folders, "all"]
            current: tab.profile.todoFolder
            countOf: f => Todo.openIn(f)
            removable: f => f !== "inbox" && f !== "all"
            nameOf: f => f === "all" ? Strings.t("allFolders") : f === "inbox" ? Strings.t("inbox") : f
            onPicked: f => {
                tab.profile.todoFolder = f;
                tab.sel = -1;
            }
            onRemoved: f => {
                if (tab.profile.todoFolder === f)
                    tab.profile.todoFolder = "inbox";
                Todo.removeFolder(f);
            }
        }

        TermInput {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            prompt: "+"
            placeholder: Strings.t("folderWord")
            onAccepted: t => {
                Todo.addFolder(t);
                tab.profile.todoFolder = t.trim().toLowerCase().replace(/\s+/g, "-") || tab.profile.todoFolder;
                text = "";
            }
            Keys.onEscapePressed: tab.forceActiveFocus()
        }

        Rule {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing * 2
            Layout.bottomMargin: Metrics.spacing
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: Strings.t("doneToday")
                color: Colors.dim
            }

            Label {
                text: Todo.doneTodayCount
                color: Todo.doneTodayCount > 0 ? Colors.fg : Colors.dim
                font.bold: !Metrics.pixel && (Todo.doneTodayCount > 0)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Todo.streak > 1

            Label {
                Layout.fillWidth: true
                text: Strings.t("streakWord")
                color: Colors.dim
            }

            Label {
                text: Strings.t("inDays").arg(Todo.streak)
                font.bold: !Metrics.pixel
            }
        }
    }

    Rule {
        vertical: true
        Layout.fillHeight: true
    }

    // ---- the folder's tasks
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
            placeholder: Strings.t("todoHint")
            onAccepted: t => {
                todoInput.feedback = Todo.add(t, tab.profile.todoFolder);
                todoInput.text = "";
                feedbackTimer.restart();
            }
            Keys.onEscapePressed: tab.forceActiveFocus()

            Timer {
                id: feedbackTimer

                interval: 3000
                onTriggered: todoInput.feedback = ""
            }
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: todoInput.feedback || Strings.t("todoHowTo")
            color: todoInput.feedback ? Colors.accent : Colors.dim
            font.pixelSize: Metrics.size(-3)
        }

        Label {
            visible: tab.tasks.length === 0
            Layout.topMargin: Metrics.spacing
            text: `— ${Strings.t("nothingHere")} —`
            color: Colors.dim
        }

        // the list, sunk in a field
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            implicitHeight: todoFlick.height + 6
            visible: tab.tasks.length > 0
            color: Colors.well

            Bevel {
                style: "sunk"
            }

            Flickable {
                id: todoFlick

                x: 3
                y: 3
                width: parent.width - 6
                height: Math.min(tab.profile.wide ? 460 : 320, todoList.implicitHeight)
                clip: true
                contentHeight: todoList.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: todoList

                    width: todoFlick.width
                    spacing: 1

                    // a ticked one slides down to the done ones, the rest close up; a new one fades in
                    move: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 260
                        }
                        NumberAnimation {
                            property: "x"
                            from: -12
                            to: 0
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            values: tab.tasks
                        }

                        Column {
                            id: task

                            required property var modelData
                            required property int index
                            readonly property bool expanded: tab.profile.todoOpen === modelData.id
                            readonly property bool picked: tab.sel === index && tab.activeFocus
                            readonly property bool struck: modelData.done || tab.ticking === modelData.id
                            readonly property bool overdue: !modelData.done && modelData.due > 0 && modelData.due < Time.now.getTime()
                            readonly property int subsDone: modelData.subs.filter(st => st.done).length

                            width: todoList.width

                            // ---- the task line: [ ] icon !!  2:00 pm  text      ▮▮▯ 2/3  ↻ week  note
                            Item {
                                width: parent.width
                                implicitHeight: taskRow.implicitHeight + 6

                                Rectangle {
                                    anchors.fill: parent
                                    visible: taskArea.containsMouse || task.expanded || task.picked
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

                                    PixIcon {
                                        name: task.struck ? "boxOn" : "boxOff"
                                    }

                                    Label {
                                        Layout.preferredWidth: Metrics.fontSize
                                        text: task.modelData.icon
                                        color: task.struck ? Colors.dim : Colors.fg
                                    }

                                    Label {
                                        Layout.preferredWidth: Metrics.fontSize * 0.6 * 3
                                        text: "!".repeat(task.modelData.prio)
                                        color: task.struck ? Colors.dim : Colors.accent
                                        font.bold: !Metrics.pixel
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
                                        color: task.struck ? Colors.dim : Colors.fg
                                        font.strikeout: task.struck
                                    }

                                    // its steps: ▮▮▯ 2/3
                                    Meter {
                                        visible: task.modelData.subs.length > 0
                                        count: Math.min(8, task.modelData.subs.length)
                                        value: task.modelData.subs.length ? task.subsDone / task.modelData.subs.length : 0
                                    }

                                    Label {
                                        visible: task.modelData.subs.length > 0
                                        text: `${task.subsDone}/${task.modelData.subs.length}`
                                        color: Colors.dim
                                    }

                                    Label {
                                        visible: task.modelData.repeat !== ""
                                        text: `↻ ${task.modelData.repeat === "weekdays" ? "wd" : task.modelData.repeat}`
                                        color: Colors.dim
                                    }

                                    // a note is inside
                                    Label {
                                        visible: task.modelData.note !== ""
                                        text: ""
                                        color: Colors.dim
                                    }

                                    Label {
                                        visible: tab.profile.todoFolder === "all"
                                        text: task.modelData.folder
                                        color: Colors.dim
                                        font.pixelSize: Metrics.size(-2)
                                    }
                                }

                                // the box ticks it; anywhere else opens the task
                                MouseArea {
                                    id: taskArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        tab.sel = task.index;
                                        tab.forceActiveFocus();
                                        if (mouse.x < Metrics.fontSize * 2.4)
                                            tab.tick(task.modelData);
                                        else
                                            tab.profile.todoOpen = task.expanded ? 0 : task.modelData.id;
                                    }
                                }
                            }

                            // ---- opened: steps, note, how often, icon, importance, folder, delete.
                            // Made only for the open task: every task carrying its own hidden editor
                            // (some 20 buttons each) was thousands of objects that nobody saw
                            Loader {
                                active: task.expanded
                                visible: active
                                x: Metrics.fontSize * 2
                                width: parent.width - x - 4

                                sourceComponent: Component {
                                    ColumnLayout {
                                        spacing: Metrics.spacing

                                        // a draft not clicked away from yet: saved once this editor is gone
                                        Component.onDestruction: Todo.saveNoteSoon()

                                        // the steps
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.topMargin: 4
                                            spacing: 0

                                            Repeater {
                                                model: task.modelData.subs

                                                Item {
                                                    id: step

                                                    required property var modelData
                                                    required property int index

                                                    Layout.fillWidth: true
                                                    implicitHeight: stepRow.implicitHeight + 4

                                                    RowLayout {
                                                        id: stepRow

                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: Metrics.spacing

                                                        PixIcon {
                                                            name: step.modelData.done ? "boxOn" : "boxOff"
                                                        }

                                                        Label {
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                            text: step.modelData.text
                                                            color: step.modelData.done ? Colors.dim : Colors.fg
                                                            font.strikeout: step.modelData.done
                                                        }

                                                        Label {
                                                            visible: stepArea.containsMouse
                                                            text: "x"
                                                            color: Colors.warn
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: stepArea

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: mouse => {
                                                            if (mouse.x > width - Metrics.fontSize * 1.5)
                                                                Todo.removeSub(task.modelData.id, step.index);
                                                            else
                                                                Todo.toggleSub(task.modelData.id, step.index);
                                                        }
                                                    }
                                                }
                                            }

                                            TermInput {
                                                Layout.fillWidth: true
                                                framed: false
                                                prompt: "+"
                                                placeholder: Strings.t("todoStep")
                                                onAccepted: t => {
                                                    Todo.addSub(task.modelData.id, t);
                                                    text = "";
                                                }
                                                Keys.onEscapePressed: tab.forceActiveFocus()
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: Math.max(48, note.contentHeight + 12)
                                            color: Colors.bg
                                            border.color: note.activeFocus ? Colors.dim : Colors.border
                                            border.width: Metrics.borderWidth

                                            TextEdit {
                                                id: note

                                                textFormat: TextEdit.PlainText // text, never html
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                text: task.modelData.note
                                                color: Colors.fg
                                                font.family: Metrics.fontFamily
                                                renderType: Metrics.pixel ? Text.NativeRendering : Text.QtRendering
                                                font.pixelSize: Metrics.size(-1)
                                                wrapMode: TextEdit.Wrap
                                                selectByMouse: true
                                                selectionColor: Colors.accent
                                                selectedTextColor: Colors.bg
                                                cursorDelegate: BlockCursor {
                                                    visible: note.activeFocus
                                                }
                                                // saved when you click away (saving on every key would
                                                // rebuild the list under the cursor), or when the profile
                                                // closes: meanwhile Todo keeps the draft, not this window
                                                onTextChanged: if (activeFocus)
                                                    Todo.editNote(task.modelData.id, text)
                                                onActiveFocusChanged: if (!activeFocus)
                                                    Todo.saveNote()
                                                Keys.onEscapePressed: tab.forceActiveFocus()

                                                Label {
                                                    visible: !note.text && !note.activeFocus
                                                    text: Strings.t("todoNoteHint")
                                                    color: Colors.dim
                                                    font.pixelSize: Metrics.size(-1)
                                                }
                                            }
                                        }

                                        // how often it comes again
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: Metrics.spacing

                                            Label {
                                                text: Strings.t("todoEvery")
                                                color: Colors.dim
                                            }

                                            Repeater {
                                                model: [["", "no"], ["day", "day"], ["weekdays", "weekdays"], ["week", "week"], ["month", "month"]]

                                                PushButton {
                                                    required property var modelData

                                                    minWidth: 0

                                                    text: modelData[1]
                                                    active: task.modelData.repeat === modelData[0]
                                                    onClicked: Todo.setRepeat(task.modelData.id, modelData[0])
                                                }
                                            }
                                        }

                                        // icon
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Repeater {
                                                model: Todo.icons

                                                PushButton {
                                                    required property string modelData

                                                    minWidth: 0

                                                    text: modelData || " "
                                                    active: task.modelData.icon === modelData
                                                    onClicked: Todo.update(task.modelData.id, { icon: modelData })
                                                }
                                            }
                                        }

                                        // importance · folder · focus · delete
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: Metrics.spacing

                                            Repeater {
                                                model: ["·", "!", "!!", "!!!"]

                                                PushButton {
                                                    required property string modelData
                                                    required property int index

                                                    minWidth: 0

                                                    text: modelData
                                                    active: task.modelData.prio === index
                                                    onClicked: Todo.update(task.modelData.id, { prio: index })
                                                }
                                            }

                                            Label {
                                                text: " "
                                            }

                                            Repeater {
                                                model: Todo.folders

                                                PushButton {
                                                    required property string modelData

                                                    minWidth: 0

                                                    text: modelData
                                                    active: task.modelData.folder === modelData
                                                    onClicked: Todo.update(task.modelData.id, { folder: modelData })
                                                }
                                            }

                                            PushButton {
                                                visible: !task.modelData.done
                                                minWidth: 0
                                                text: Strings.t("focusOnIt")
                                                onClicked: {
                                                    Focus.start(task.modelData.id);
                                                    tab.profile.show("focus");
                                                }
                                            }

                                            PushButton {
                                                minWidth: 0
                                                text: Strings.t("deleteWord")
                                                onClicked: {
                                                    tab.profile.todoOpen = 0;
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
                }
            }
        }

        Rule {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            visible: tab.tasks.length > 0
        }

        RowLayout {
            Layout.fillWidth: true
            visible: tab.tasks.length > 0

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Strings.t("todoKeys")
                color: Colors.dim
                font.pixelSize: Metrics.size(-3)
            }

            PushButton {
                visible: tab.tasks.some(t => t.done)
                minWidth: 0
                text: Strings.t("clearDone")
                onClicked: Todo.clearDone(tab.profile.todoFolder)
            }
        }
    }
}
