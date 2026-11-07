import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.utils

// The focus timer (services/Focus.qml), big:
//
//   on: kawt readme                         [ A task… ]  (•) 25/5  ( ) 50/10
//
//   18:42
//   [▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮                    ]
//   of 25:00 · then 5 min break
//
//   [ ❚❚ ] [ Skip ] [ Stop ]                      [x] Do not disturb while it works
//   ───────────────────────────────────────────────────────────────────────
//   week  ▯ ▯ ▯ ▯ ▯ ▯ ▯  (a column a day, a block a round)
//   today 3 of 4 · 1h 15m                                       goal [−] 4 [+]
ColumnLayout {
    id: tab

    required property var profile
    property bool picking: false // the list of tasks to pick from is open
    property real picked: 0 // the task the next round is on (0: none)
    readonly property string pickedText: Todo.tasks.find(t => t.id === picked)?.text ?? ""

    spacing: Metrics.spacing

    // what it's on: a task, or nothing in particular
    RowLayout {
        Layout.topMargin: Metrics.spacing
        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            text: Strings.t("focusOn")
            color: Colors.dim
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Focus.running ? (Focus.taskText || Strings.t("focusNothing")) : tab.pickedText || Strings.t("focusNothing")
        }

        PushButton {
            visible: !Focus.running
            minWidth: 0
            text: tab.picking ? Strings.t("close") : Strings.t("focusTask")
            active: tab.picking
            onClicked: tab.picking = !tab.picking
        }

        // work / break lengths: one of two
        Repeater {
            model: [[25, 5], [50, 10]]

            Check {
                required property var modelData

                Layout.leftMargin: 6
                radio: true
                text: `${modelData[0]}/${modelData[1]}`
                checked: Focus.workMin === modelData[0] && Focus.breakMin === modelData[1]
                onToggled: Focus.setLengths(modelData[0], modelData[1])
            }
        }
    }

    // a task to work on: the open ones, the important and timed first
    ColumnLayout {
        Layout.fillWidth: true
        visible: tab.picking
        spacing: 0

        Repeater {
            model: tab.picking ? [{ id: 0, text: Strings.t("focusNothing") }, ...Todo.sorted.filter(t => !t.done).slice(0, 8)] : []

            Item {
                id: pick

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: pickLabel.implicitHeight + 4

                Rectangle {
                    anchors.fill: parent
                    visible: pickArea.containsMouse
                    color: Colors.hoverFill
                }

                Label {
                    id: pickLabel

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: (tab.picked === pick.modelData.id ? "> " : "  ") + pick.modelData.text
                    color: tab.picked === pick.modelData.id ? Colors.accent : pick.modelData.id ? Colors.fg : Colors.dim
                }

                MouseArea {
                    id: pickArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tab.picked = pick.modelData.id;
                        tab.picking = false;
                    }
                }
            }
        }
    }

    // the time, big
    Label {
        Layout.topMargin: Metrics.spacing
        text: Focus.running ? Focus.clock : `${Focus.workMin}:00`
        color: Focus.phase === "break" ? Colors.dim : Colors.fg
        font.pixelSize: Metrics.times(4)
        font.weight: Font.Light
    }

    // how far, in red blocks
    Segments {
        Layout.fillWidth: true
        value: Focus.progress
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: Focus.phase === "break" ? Strings.t("focusBreakLine")
            : Focus.paused ? Strings.t("focusPausedLine").arg(Focus.clock)
            : Strings.t("focusOfLine").arg(Focus.workMin).arg(Focus.breakMin)
        color: Colors.dim
    }

    RowLayout {
        Layout.topMargin: Metrics.spacing
        Layout.fillWidth: true
        spacing: Metrics.spacing

        PushButton {
            visible: !Focus.running
            text: Strings.t("focusStart")
            onClicked: {
                tab.picking = false;
                Focus.start(tab.picked);
            }
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
            text: Strings.t("focusSkip")
            onClicked: Focus.skip()
        }

        PushButton {
            visible: Focus.running
            minWidth: 0
            text: Strings.t("focusStop")
            onClicked: Focus.stop()
        }

        Item {
            Layout.fillWidth: true
        }

        Check {
            text: Strings.t("focusQuiet")
            checked: Focus.quiet
            onToggled: Focus.setQuiet(!Focus.quiet)
        }
    }

    Rule {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
    }

    // the week, and today's rounds with the goal (as many blocks a day) beside it
    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.padding

        WeekBars {
            Layout.fillWidth: true
            streak: false
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignBottom
            spacing: 4

            Label {
                Layout.alignment: Qt.AlignRight
                text: Strings.t("focusGoal").arg(Focus.todayRounds).arg(Focus.goal) + (Focus.todayMs > 0 ? ` · ${Fmt.uptime(Focus.todayMs / 1000)}` : "")
                color: Focus.todayRounds >= Focus.goal ? Colors.accent : Colors.dim
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Metrics.spacing

                Label {
                    text: Strings.t("goalWord")
                    color: Colors.dim
                }

                PushButton {
                    minWidth: 24
                    text: "−"
                    onClicked: Focus.setGoal(Focus.goal - 1)
                }

                Label {
                    text: Focus.goal
                }

                PushButton {
                    minWidth: 24
                    text: "+"
                    onClicked: Focus.setGoal(Focus.goal + 1)
                }
            }
        }
    }
}
