import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// The clock's panel, the old way: the time big, the date; the month with ◄ ►, its days in a
// sunk field, today red, the days with a task underlined; today's tasks under it.
//
//   14:53 :07                     sat, 7 november
//   [◄]          november 2026          [►]
//   ┌──────────────────────────────────────┐
//   │ mo  tu  we  th  fr  sa  su           │
//   │                          1           │
//   │  2   3   4   5   6  [7]  8   …       │
//   └──────────────────────────────────────┘
//   today
//   ▤ 15:30 call mom                 37 min
Popover {
    id: root

    property int monthOffset: 0
    readonly property var locale: Qt.locale(Strings.ru ? "ru_RU" : "en_US")
    // from Time.day, not Time.now: the grid below is built again only when the date changes,
    // not on every tick of the clock
    readonly property date today: {
        const [y, m, d] = Time.day.split("-").map(Number);
        return new Date(y, m - 1, d);
    }
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property bool isCurrentMonth: monthOffset === 0
    readonly property var cells: {
        const startOffset = (shown.getDay() + 6) % 7;
        const daysInMonth = new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < startOffset; i++)
            out.push("");
        for (let d = 1; d <= daysInMonth; d++)
            out.push(String(d));
        return out;
    }
    // the shown month's days with an open task on them
    readonly property var busy: {
        const out = {};
        for (const t of Todo.tasks) {
            if (t.done || !t.due)
                continue;
            const d = new Date(t.due);
            if (d.getFullYear() === shown.getFullYear() && d.getMonth() === shown.getMonth())
                out[d.getDate()] = true;
        }
        return out;
    }

    name: "calendar"
    title: Strings.t("calendarTitle")
    head: false
    cardWidth: 300
    settingsPage: "bar"
    note: Strings.t("weekNo").arg(weekNumber())

    onPanelOpened: monthOffset = 0

    // ISO-8601 week number
    function weekNumber(): int {
        const d = new Date(Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()));
        const day = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }

    // 37 min / 2 h 10 min
    function until(ms: real): string {
        const m = Math.max(0, Math.round((ms - Time.now.getTime()) / 60000));
        if (m < 60)
            return Strings.t("inMin").arg(m);
        return m % 60 ? Strings.t("inHoursMin").arg(Math.floor(m / 60)).arg(m % 60) : Strings.t("inHours").arg(m / 60);
    }

    // the time, big; the date
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Label {
            text: Time.fmt(Time.now)
            font.pixelSize: Metrics.fontSize * 2
        }

        Label {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 2
            text: `:${Qt.formatTime(Time.now, "ss")}`
            color: Colors.dim
        }

        Item {
            Layout.fillWidth: true
        }

        Label {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 2
            text: root.locale.toString(root.today, "ddd, d MMMM").toLowerCase()
            color: Colors.dim
        }
    }

    RowLayout {
        Layout.fillWidth: true

        ArrowButton {
            dir: "left"
            onClicked: root.monthOffset--
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: `${root.locale.standaloneMonthName(root.shown.getMonth(), Locale.LongFormat)} ${root.shown.getFullYear()}`.toLowerCase()
            color: root.isCurrentMonth ? Colors.fg : Colors.accent

            // back to this month
            MouseArea {
                anchors.fill: parent
                onClicked: root.monthOffset = 0
            }
        }

        ArrowButton {
            dir: "right"
            onClicked: root.monthOffset++
        }
    }

    // the month, sunk in a field
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight + 10
        color: Colors.well

        Bevel {
            style: "sunk"
        }

        GridLayout {
            id: grid

            x: 5
            y: 5
            width: parent.width - 10
            columns: 7
            rowSpacing: 2
            columnSpacing: 2

            // the day names, monday first
            Repeater {
                model: [1, 2, 3, 4, 5, 6, 0]

                Label {
                    required property int modelData

                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.locale.dayName(modelData, Locale.ShortFormat).toLowerCase()
                    color: Colors.dim
                }
            }

            Repeater {
                model: root.cells

                Rectangle {
                    id: cell

                    required property string modelData
                    readonly property bool isToday: root.isCurrentMonth && modelData === String(root.today.getDate())

                    Layout.fillWidth: true
                    implicitHeight: day.implicitHeight + 4
                    color: isToday ? Colors.accent : "transparent"

                    Label {
                        id: day

                        anchors.centerIn: parent
                        text: cell.modelData
                        color: cell.isToday ? Colors.onAccent : Colors.fg
                        font.underline: cell.modelData !== "" && root.busy[Number(cell.modelData)] === true
                    }
                }
            }
        }
    }

    // today's timed tasks (Today's list)
    ColumnLayout {
        Layout.fillWidth: true
        visible: Todo.today.length > 0
        spacing: 2

        Label {
            text: Strings.t("today").toLowerCase()
            color: Colors.dim
        }

        Repeater {
            model: ScriptModel {
                values: Todo.today.slice(0, 5)
            }

            RowLayout {
                id: task

                required property var modelData

                Layout.fillWidth: true
                spacing: 6

                PixIcon {
                    name: "notes"
                }

                Label {
                    text: Time.fmt(new Date(task.modelData.due))
                    color: task.modelData.due < Time.now.getTime() ? Colors.warn : Colors.fg
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: task.modelData.text
                }

                Label {
                    visible: task.modelData.due > Time.now.getTime()
                    text: visible ? root.until(task.modelData.due) : ""
                    color: Colors.dim
                }
            }
        }
    }
}
