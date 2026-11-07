import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// What the today window opens with: the day in one look, the old way.
//
//   tasks for today                 2 of 5    ┌ Focus ──────────────┐
//   ┌───────────────────────────────────────┐ │ 18:04 / 25:00        │
//   │■ 15:30 call mom              !! 37m   │ │ ▮▮▮▮▮▮▮              │
//   │□ 19:00 gym                      ! 4h  │ │ kawt readme          │
//   │□       write the readme               │ │ [ ❚❚ ] [ Stop ]      │
//   │☑ 09:00 standup (struck through)       │ └──────────────────────┘
//   └───────────────────────────────────────┘
//   [+ new: "14:30 call mom !!"          ]
//   ▯▯▯▯▯▯▯
//   week  mon tue wed thu fri sat sun                       streak: 4 days
//
// The list: open tasks due today or before (by time), then open ones without a time
// (important first), then the ones ticked off today, struck through. The one under the pointer
// or picked with ↑ ↓ is red; x or space ticks it, enter opens it in the tasks tab, n writes a
// new one. A click on the box ticks it, on the words opens it
ColumnLayout {
    id: tab

    required property var profile
    readonly property var dated: Todo.dueToday
    readonly property var undated: Todo.sorted.filter(t => !t.done && !t.due).slice(0, Math.max(2, 6 - dated.length))
    readonly property var done: Todo.doneToday.slice(-3)
    readonly property var rows: [...dated, ...undated, ...done].slice(0, 6) // the rest: the tasks tab
    property int current: 0
    readonly property var picked: rows[Math.min(current, rows.length - 1)] ?? null
    readonly property int rowHeight: Metrics.fontSize + 9
    readonly property var locale: Qt.locale(Strings.ru ? "ru_RU" : "en_US")

    spacing: Metrics.spacing
    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onUpPressed: current = Math.max(0, current - 1)
    Keys.onDownPressed: current = Math.min(rows.length - 1, current + 1)
    Keys.onSpacePressed: tick()
    Keys.onReturnPressed: {
        if (picked)
            profile.openTask(picked);
    }
    Keys.onPressed: event => {
        if (event.text === "x") {
            tick();
            event.accepted = true;
        } else if (event.text === "n") {
            add.input.forceActiveFocus();
            event.accepted = true;
        }
    }

    function tick(): void {
        if (picked)
            Todo.toggle(picked.id);
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        spacing: Metrics.padding

        // ---- the day's tasks
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                Label {
                    Layout.fillWidth: true
                    text: Strings.t("todayList")
                    color: Colors.dim
                }

                Label {
                    readonly property int all: Todo.doneToday.length + Todo.dueToday.length

                    visible: all > 0
                    text: Strings.t("nOfM").arg(Todo.doneToday.length).arg(all)
                    color: Todo.dueToday.length === 0 ? Colors.accent : Colors.dim
                }
            }

            // the list, sunk in a field
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(5, tab.rows.length) * tab.rowHeight + 6
                color: Colors.well

                Bevel {
                    style: "sunk"
                }

                Label {
                    anchors.centerIn: parent
                    visible: tab.rows.length === 0
                    text: `— ${Strings.t("freeDay")} —`
                    color: Colors.dim
                }

                Column {
                    x: 3
                    y: 3
                    width: parent.width - 6

                    Repeater {
                        model: ScriptModel {
                            values: tab.rows
                        }

                        Rectangle {
                            id: task

                            required property var modelData
                            required property int index
                            readonly property bool picked: index === tab.current
                            readonly property bool overdue: !modelData.done && modelData.due > 0 && modelData.due < Time.now.getTime()
                            readonly property color ink: picked ? Colors.onAccent : modelData.done ? Colors.dim : Colors.fg

                            width: parent.width
                            height: tab.rowHeight
                            color: picked ? Colors.accent : "transparent"

                            PixIcon {
                                id: box

                                x: 3
                                anchors.verticalCenter: parent.verticalCenter
                                name: task.modelData.done ? "boxOn" : "boxOff"
                            }

                            Label {
                                id: time

                                x: box.x + box.width + 6
                                width: Metrics.fontSize * 0.6 * 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: task.modelData.due ? Time.fmt(new Date(task.modelData.due)) : ""
                                color: task.picked ? Colors.onAccent : task.overdue ? Colors.warn : Colors.dim
                            }

                            Label {
                                x: time.x + time.width
                                width: when.x - x - 6
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: task.modelData.text
                                color: task.ink
                                font.strikeout: task.modelData.done
                            }

                            // !! in 37m: how important, how soon
                            Label {
                                id: when

                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: task.modelData.done ? "" : [
                                    task.modelData.prio > 0 ? "!".repeat(task.modelData.prio) : "",
                                    task.modelData.due > Time.now.getTime() ? tab.profile.until(task.modelData.due) : ""
                                ].filter(s => s).join(" ")
                                color: task.picked ? Colors.onAccent : Colors.accent
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: tab.current = task.index
                                onClicked: mouse => {
                                    if (mouse.x < box.x + box.width + 3)
                                        Todo.toggle(task.modelData.id);
                                    else
                                        tab.profile.openTask(task.modelData);
                                }
                            }
                        }
                    }
                }
            }

            TermInput {
                id: add

                property string feedback: ""

                Layout.fillWidth: true
                Layout.topMargin: 2
                prompt: "+"
                placeholder: Strings.t("newTask")
                onAccepted: t => {
                    add.feedback = Todo.add(t, "inbox");
                    add.text = "";
                    addFeedback.restart();
                    tab.forceActiveFocus();
                }
                Keys.onEscapePressed: event => {
                    // the first esc leaves the field, the next one closes the window
                    if (add.text !== "" || add.input.activeFocus) {
                        add.text = "";
                        tab.forceActiveFocus();
                    } else {
                        event.accepted = false;
                    }
                }

                Timer {
                    id: addFeedback

                    interval: 3000
                    onTriggered: add.feedback = ""
                }
            }

            Label {
                visible: add.feedback !== ""
                text: add.feedback
                color: Colors.accent
            }
        }

        // ---- the focus timer, small
        Group {
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Math.round(Metrics.fontSize * 17)
            title: Focus.phase === "break" ? Strings.t("breakTime") : Strings.t("tab_focus")

            RowLayout {
                spacing: Metrics.spacing

                Label {
                    text: Focus.running ? Focus.clock : `${Focus.workMin}:00`
                    font.pixelSize: Metrics.fontSize * 2
                }

                Label {
                    Layout.alignment: Qt.AlignBottom
                    text: Focus.paused ? Strings.t("focusPaused") : `/ ${Focus.phase === "break" ? Focus.breakMin : Focus.workMin}:00`
                    color: Colors.dim
                }
            }

            Segments {
                Layout.fillWidth: true
                value: Focus.progress
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Focus.running ? (Focus.taskText || Strings.t("focusNothing")) : Strings.t("focusGoal").arg(Focus.todayRounds).arg(Focus.goal)
                color: Focus.running ? Colors.fg : Colors.dim
            }

            RowLayout {
                spacing: Metrics.spacing

                PushButton {
                    visible: !Focus.running
                    minWidth: 0
                    text: Strings.t("focusStart")
                    onClicked: Focus.start(tab.picked && !tab.picked.done ? tab.picked.id : 0)
                }

                PushButton {
                    visible: !Focus.running
                    minWidth: 0
                    text: Strings.t("focusOnTask")
                    onClicked: tab.profile.show("focus")
                }

                PushButton {
                    visible: Focus.running
                    minWidth: 30
                    text: Focus.paused ? "▶" : "❚❚"
                    active: Focus.paused
                    onClicked: Focus.paused ? Focus.resume() : Focus.pause()
                }

                PushButton {
                    visible: Focus.running
                    minWidth: 0
                    text: Strings.t("focusStop")
                    onClicked: Focus.stop()
                }
            }
        }
    }

    // ---- the week's focus: a column a day, a block a round
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        spacing: 8

        Label {
            Layout.alignment: Qt.AlignBottom
            Layout.rightMargin: 8
            text: Strings.t("weekWord")
            color: Colors.dim
        }

        Repeater {
            model: Focus.week

            ColumnLayout {
                id: day

                required property var modelData
                readonly property int most: Math.max(Focus.goal, modelData.rounds, 1)

                spacing: 2

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 14
                    implicitHeight: 36
                    color: Colors.well

                    Bevel {
                        style: "sunk"
                    }

                    Repeater {
                        model: Math.min(day.modelData.rounds, day.most)

                        Rectangle {
                            required property int index
                            readonly property real step: (36 - 6) / day.most

                            x: 3
                            y: Math.round(36 - 3 - (index + 1) * step) + 1
                            width: 8
                            height: Math.max(1, Math.round(step) - 1)
                            color: day.modelData.isToday ? Colors.accent : Colors.dim
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: tab.locale.toString(day.modelData.date, "ddd").toLowerCase()
                    color: day.modelData.isToday ? Colors.accent : Colors.dim
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Label {
            Layout.alignment: Qt.AlignBottom
            visible: Todo.streak > 0
            text: Strings.t("streakIs").arg(Strings.count(Todo.streak, "day"))
            color: Colors.dim
        }
    }
}
