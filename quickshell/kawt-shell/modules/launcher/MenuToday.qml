import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// The start menu's today: the date and the time, the tasks still open (today's first; a click
// ticks one off, another takes it back), what's done today struck through below them, and a
// field for a new one, written the todo tab's way: 2pm call mom #family !!
ColumnLayout {
    id: root

    readonly property var open: [...Todo.dueToday, ...Todo.sorted.filter(t => !t.done && !Todo.dueToday.includes(t))]
    readonly property int rowHeight: Metrics.fontSize + 12
    property string said: "" // what adding a task said

    spacing: Metrics.spacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing * 2

        Label {
            text: Qt.formatDate(Time.now, "ddd dd.MM").toLowerCase()
            font.bold: !Metrics.pixel
            font.pixelSize: Metrics.size(2)
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: `${Time.fmt(Time.now)} · ${Todo.open} open · ${Todo.doneTodayCount} done today`
            color: Colors.dim
        }
    }

    Well {
        id: well

        readonly property var shown: [...root.open, ...Todo.doneToday].slice(0, Math.max(1, Math.floor((height - 6) / root.rowHeight)))

        Layout.fillWidth: true
        Layout.fillHeight: true

        Column {
            anchors.fill: parent
            anchors.margins: 3

            Repeater {
                model: well.shown

                Item {
                    id: task

                    required property var modelData
                    readonly property bool late: !modelData.done && modelData.due > 0 && modelData.due < Time.now.getTime()

                    width: parent.width
                    height: root.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        visible: area.containsMouse
                        color: Colors.hoverFill
                    }

                    // the box: sunk, an x in it when done
                    Rectangle {
                        id: box

                        x: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(Metrics.fontSize * 0.95)
                        height: width
                        color: Colors.bevel ? Colors.bg : "transparent"

                        Bevel {
                            style: "sunk"
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: task.modelData.done
                            text: "x"
                            font.bold: !Metrics.pixel
                            font.pixelSize: Metrics.size(-2)
                        }
                    }

                    Label {
                        anchors.left: box.right
                        anchors.leftMargin: Metrics.spacing
                        anchors.right: due.left
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: task.modelData.text
                        color: task.modelData.done ? Colors.dim : Colors.fg
                        font.strikeout: task.modelData.done
                    }

                    // when: the time today, the day for later ones; late ones in the warning color
                    Label {
                        id: due

                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !task.modelData.done && task.modelData.due > 0
                        text: !visible ? "" : Qt.formatDate(new Date(task.modelData.due), "yyyy-MM-dd") === Time.day ? Time.fmt(new Date(task.modelData.due)) : Qt.formatDate(new Date(task.modelData.due), "dd.MM")
                        color: task.late ? Colors.warn : Colors.dim
                        font.pixelSize: Metrics.size(-2)
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Todo.toggle(task.modelData.id)
                    }
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: well.shown.length === 0
            text: Todo.loaded ? "nothing to do" : "..."
            color: Colors.dim
        }
    }

    TermInput {
        Layout.fillWidth: true
        prompt: "+"
        placeholder: "a new task: 2pm call mom #family !!"
        onAccepted: t => {
            if (!t.trim())
                return;
            root.said = Todo.add(t, "inbox");
            text = "";
        }
        Keys.onEscapePressed: Panels.close()
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: root.said || "a click ticks a task off · folders, steps and repeats: the profile's todo"
        color: Colors.dim
        font.pixelSize: Metrics.size(-2)
    }
}
