import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.utils

// The focus timer (services/Focus.qml), big:
//
//   on: kawt readme  [change]                               [25/5] 50/10
//
//   18:42
//   ▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯     the red one is now
//   of 25:00 · then 5 min break
//
//   [||] [skip] [stop]                                  [x] dnd while it works
//
//   this week  mon ▮▮▮▯  tue ▮▮▯▯  wed ▯▯▯▯ ...          a segment a round, the goal's many
//   today 3 of 4 · 1h 15m                               [-] goal 4 [+]
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
            text: "on:"
            color: Colors.dim
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Focus.running ? (Focus.taskText || "nothing in particular") : tab.pickedText || "nothing in particular"
        }

        BracketButton {
            visible: !Focus.running
            label: tab.picking ? "close" : "a task"
            active: tab.picking
            onClicked: tab.picking = !tab.picking
        }

        // work / break lengths
        Repeater {
            model: [[25, 5], [50, 10]]

            BracketButton {
                required property var modelData
                readonly property bool chosen: Focus.workMin === modelData[0] && Focus.breakMin === modelData[1]

                label: `${modelData[0]}/${modelData[1]}`
                textColor: chosen ? Colors.accent : Colors.dim
                onClicked: Focus.setLengths(modelData[0], modelData[1])
            }
        }
    }

    // a task to work on: the open ones, the important and timed first
    ColumnLayout {
        Layout.fillWidth: true
        visible: tab.picking
        spacing: 0

        Repeater {
            model: tab.picking ? [{ id: 0, text: "nothing in particular" }, ...Todo.sorted.filter(t => !t.done).slice(0, 8)] : []

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
        font.pixelSize: Math.round(Metrics.fontSize * 4)
        font.weight: Font.Light
    }

    // how far: the red segment is now
    LevelSlider {
        Layout.fillWidth: true
        enabled: false
        playhead: Focus.running
        value: Focus.progress
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: Focus.phase === "break" ? `break · then the next round waits for you`
            : Focus.paused ? `paused · ${Focus.clock} left`
            : `of ${Focus.workMin}:00 · then ${Focus.breakMin} min break`
        color: Colors.dim
    }

    RowLayout {
        Layout.topMargin: Metrics.spacing
        Layout.fillWidth: true
        spacing: Metrics.spacing

        BracketButton {
            visible: !Focus.running
            label: "start"
            textColor: Colors.accent
            onClicked: {
                tab.picking = false;
                Focus.start(tab.picked);
            }
        }

        BracketButton {
            visible: Focus.running
            label: Focus.paused ? ">" : "||"
            active: Focus.paused
            onClicked: Focus.paused ? Focus.resume() : Focus.pause()
        }

        BracketButton {
            visible: Focus.running
            label: "skip"
            onClicked: Focus.skip()
        }

        BracketButton {
            visible: Focus.running
            label: "stop"
            onClicked: Focus.stop()
        }

        Item {
            Layout.fillWidth: true
        }

        BracketButton {
            label: Focus.quiet ? "x" : " "
            onClicked: Focus.setQuiet(!Focus.quiet)
        }

        Label {
            text: "dnd while it works"
            color: Colors.dim
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    // the week: a segment a round, as many as the goal
    Flow {
        Layout.fillWidth: true
        spacing: Metrics.padding

        Label {
            text: "this week"
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
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: `today ${Focus.todayRounds} of ${Focus.goal}` + (Focus.todayMs > 0 ? ` · ${Fmt.uptime(Focus.todayMs / 1000)}` : "")
            color: Focus.todayRounds >= Focus.goal ? Colors.accent : Colors.dim
        }

        Label {
            text: "goal"
            color: Colors.dim
        }

        BracketButton {
            label: "-"
            onClicked: Focus.setGoal(Focus.goal - 1)
        }

        Label {
            text: Focus.goal
        }

        BracketButton {
            label: "+"
            onClicked: Focus.setGoal(Focus.goal + 1)
        }
    }
}
