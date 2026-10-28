import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.utils

// What the profile opens with: the day in one look.
//
//   tue 28.10  14:32 · up 3h 12m                                  > stay curious
//
//   today                       2 of 5 done      ┌ focus ─────────────┐
//   [x] 09:00  standup                           │ 18:42   of 25:00   │
//   [ ] 14:30  call mom   !!  in 58m             │ ▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯   │
//   [ ]        buy milk                          │ kawt readme        │
//   + 2pm call mom #family !!                    │ [||] [stop]        │
//                                                └────────────────────┘
//   week  mon ▮▮▮▯  tue ▮▮▯▯ ...                             3 focus · 1h 15m today
//   ────────────────────────────────────────────────────────────────────
//   cpu ▁▂▅▇▆▃▂ 12%   mem 61%   disk 61%   net ↓1.2M ↑34K   54°C
//
// The list: open tasks due today or before (by time), then open ones without a time
// (important first), then the ones ticked off today, struck through. A click on the box ticks
// it, on the text opens it in todo
ColumnLayout {
    id: tab

    required property var profile
    readonly property var dated: Todo.dueToday
    readonly property var undated: Todo.sorted.filter(t => !t.done && !t.due).slice(0, Math.max(2, 6 - dated.length))
    readonly property var done: Todo.doneToday.slice(-3)
    readonly property var rows: [...dated, ...undated, ...done]

    spacing: Metrics.spacing

    // the date, the motto
    RowLayout {
        Layout.topMargin: Metrics.spacing
        Layout.fillWidth: true
        spacing: Metrics.spacing
        opacity: tab.profile.boot > 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        Label {
            text: Qt.formatDate(Time.now, "ddd dd.MM").toLowerCase()
            font.bold: true
        }

        Label {
            text: `${Time.fmt(Time.now)} · up ${Fmt.uptime(SysInfo.uptime)}`
            color: Colors.dim
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: Settings.motto === "" ? "" : `> ${Settings.motto === "fortune" ? tab.profile.fortune : Settings.motto}`
            color: Colors.dim
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        spacing: Metrics.padding * 2
        opacity: tab.profile.boot > 1 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        // ---- the day's tasks
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 0

            RowLayout {
                Layout.fillWidth: true

                Label {
                    Layout.fillWidth: true
                    text: "today"
                    color: Colors.dim
                }

                Label {
                    readonly property int all: Todo.doneToday.length + Todo.dueToday.length

                    visible: all > 0
                    text: `${Todo.doneToday.length} of ${all} done`
                    color: Todo.dueToday.length === 0 ? Colors.accent : Colors.dim
                }
            }

            Label {
                Layout.topMargin: 4
                visible: tab.rows.length === 0
                text: "-- a free day --"
                color: Colors.dim
            }

            Repeater {
                model: ScriptModel {
                    values: tab.rows
                }

                Item {
                    id: task

                    required property var modelData
                    readonly property bool overdue: !modelData.done && modelData.due > 0 && modelData.due < Time.now.getTime()

                    Layout.fillWidth: true
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
                        spacing: Metrics.spacing

                        Brackets {
                            text: task.modelData.done ? "x" : " "
                            look: task.modelData.done ? "off" : task.modelData.prio >= 2 ? "on" : ""
                        }

                        Label {
                            Layout.preferredWidth: Metrics.fontSize * 0.6 * 5
                            text: task.modelData.due ? Time.fmt(new Date(task.modelData.due)) : ""
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
                            visible: !task.modelData.done && task.modelData.prio > 0
                            text: "!".repeat(task.modelData.prio)
                            color: Colors.accent
                        }

                        Label {
                            visible: !task.modelData.done && task.modelData.due > Time.now.getTime()
                            text: visible ? `in ${tab.profile.until(task.modelData.due)}` : ""
                            color: Colors.dim
                        }
                    }

                    MouseArea {
                        id: taskArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.x < Metrics.fontSize * 2.4)
                                Todo.toggle(task.modelData.id);
                            else
                                tab.profile.openTask(task.modelData);
                        }
                    }
                }
            }

            TermInput {
                id: add

                property string feedback: ""

                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                framed: false
                prompt: "+"
                placeholder: "14:30 call mom !!"
                onAccepted: t => {
                    add.feedback = Todo.add(t, "inbox");
                    add.text = "";
                    addFeedback.restart();
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
                font.pixelSize: Metrics.fontSize - 2
            }
        }

        // ---- the focus timer, small
        TitledBox {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: titleOverhang
            implicitWidth: Math.round(Metrics.fontSize * 15)
            implicitHeight: focusCol.implicitHeight + Metrics.padding * 2 + titleOverhang
            title: Focus.phase === "break" ? "break" : "focus"

            ColumnLayout {
                id: focusCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Metrics.padding
                anchors.topMargin: Metrics.padding + parent.titleOverhang
                spacing: 4

                RowLayout {
                    spacing: Metrics.spacing

                    Label {
                        text: Focus.running ? Focus.clock : `${Focus.workMin}:00`
                        font.bold: true
                    }

                    Label {
                        text: Focus.paused ? "paused" : Focus.running ? `of ${Focus.phase === "break" ? Focus.breakMin : Focus.workMin}:00` : `+ ${Focus.breakMin} break`
                        color: Colors.dim
                    }
                }

                LevelSlider {
                    Layout.fillWidth: true
                    enabled: false
                    playhead: Focus.running
                    value: Focus.progress
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Focus.running ? (Focus.taskText || "nothing in particular") : `today ${Focus.todayRounds} of ${Focus.goal}`
                    color: Focus.running ? Colors.fg : Colors.dim
                }

                Row {
                    spacing: Metrics.spacing

                    BracketButton {
                        visible: !Focus.running
                        label: "start"
                        textColor: Colors.accent
                        onClicked: Focus.start(0)
                    }

                    BracketButton {
                        visible: !Focus.running
                        label: "on a task"
                        onClicked: tab.profile.show("focus")
                    }

                    BracketButton {
                        visible: Focus.running
                        label: Focus.paused ? ">" : "||"
                        active: Focus.paused
                        onClicked: Focus.paused ? Focus.resume() : Focus.pause()
                    }

                    BracketButton {
                        visible: Focus.running
                        label: "stop"
                        onClicked: Focus.stop()
                    }
                }
            }
        }
    }

    // ---- the week's focus
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        spacing: Metrics.padding
        opacity: tab.profile.boot > 2 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        Label {
            text: "week"
            color: Colors.dim
        }

        Repeater {
            model: Focus.week

            Row {
                required property var modelData

                spacing: 4

                Label {
                    text: modelData.day
                    color: modelData.isToday ? Colors.accent : Colors.dim
                }

                Meter {
                    anchors.verticalCenter: parent.verticalCenter
                    count: Math.max(Focus.goal, modelData.rounds)
                    value: modelData.rounds / Math.max(Focus.goal, modelData.rounds)
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    // ---- the machine, in one line
    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        opacity: tab.profile.boot > 3 ? 1 : 0
        text: [
            `cpu ${Fmt.spark(SysInfo.cpuHistory.slice(-8))} ${Math.round(SysInfo.cpu * 100)}%`,
            `mem ${Math.round(SysInfo.mem * 100)}%`,
            `disk ${Math.round(SysInfo.disk * 100)}%`,
            `net ↓${Fmt.rate(NetStats.rx).trim()} ↑${Fmt.rate(NetStats.tx).trim()}`,
            SysInfo.cpuTemp >= 0 ? `${Math.round(SysInfo.cpuTemp)}°C` : ""
        ].filter(s => s).join("   ")
        color: Colors.dim

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }
    }
}
