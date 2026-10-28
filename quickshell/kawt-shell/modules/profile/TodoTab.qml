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

RowLayout {
    required property var profile

    spacing: Metrics.padding

    // folders
    ColumnLayout {
        Layout.preferredWidth: profile.wide ? 190 : 140
        Layout.maximumWidth: profile.wide ? 190 : 140
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
                readonly property bool current: profile.todoFolder === modelData

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
                            if (profile.todoFolder === folderRow.modelData)
                                profile.todoFolder = "inbox";
                            Todo.removeFolder(folderRow.modelData);
                        } else {
                            profile.todoFolder = folderRow.modelData;
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
                profile.todoFolder = t.trim().toLowerCase().replace(/\s+/g, "-") || profile.todoFolder;
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
                todoInput.feedback = Todo.add(t, profile.todoFolder);
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
            visible: profile.todoTasks.length === 0
            Layout.topMargin: Metrics.spacing
            text: "-- nothing here --"
            color: Colors.dim
        }

        Flickable {
            id: todoFlick

            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            Layout.preferredHeight: Math.min(profile.wide ? 460 : 320, todoList.implicitHeight)
            visible: profile.todoTasks.length > 0
            clip: true
            contentHeight: todoList.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: todoList

                width: todoFlick.width
                spacing: 1

                Repeater {
                    model: ScriptModel {
                        values: profile.todoTasks
                    }

                    Column {
                        id: task

                        required property var modelData
                        readonly property bool expanded: profile.todoOpen === modelData.id
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
                                    visible: profile.todoFolder === "all"
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
                                        profile.todoOpen = task.expanded ? 0 : task.modelData.id;
                                }
                            }
                        }

                        // ---- opened: note, icon, importance, folder, delete. Made only for the open task:
                        // every task carrying its own hidden editor (some 20 buttons each) was thousands of
                        // objects that nobody saw
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

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 4
                                        implicitHeight: Math.max(60, note.contentHeight + 12)
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
                                            font.pixelSize: Metrics.fontSize - 1
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
                                                profile.todoOpen = 0;
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

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            visible: profile.todoTasks.length > 0

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `-- ${Todo.openIn(profile.todoFolder)} open · click a task to open it · reminders go to [log] --`
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 3
            }

            BracketButton {
                visible: profile.todoTasks.some(t => t.done)
                label: "clear done"
                bordered: false
                onClicked: Todo.clearDone(profile.todoFolder)
            }
        }
    }
}
