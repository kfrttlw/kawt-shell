import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Popover {
    id: root

    property int monthOffset: 0
    readonly property date today: Time.now
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

    name: "calendar"
    title: Qt.formatDate(today, "ddd dd.MM.yyyy").toLowerCase()
    cardWidth: 240

    onOpenChanged: if (open)
        monthOffset = 0

    RowLayout {
        Layout.fillWidth: true

        BracketButton {
            label: "<"
            bordered: false
            onClicked: root.monthOffset--
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(root.shown, "MMMM yyyy").toLowerCase()
            color: root.isCurrentMonth ? Colors.fg : Colors.accent

            MouseArea {
                anchors.fill: parent
                onClicked: root.monthOffset = 0
            }
        }

        BracketButton {
            label: ">"
            bordered: false
            onClicked: root.monthOffset++
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: ["mo", "tu", "we", "th", "fr", "sa", "su"]

            Label {
                required property string modelData
                required property int index

                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index >= 5 ? Colors.accent : Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }
        }

        Repeater {
            model: root.cells

            Rectangle {
                required property string modelData
                readonly property bool isToday: root.isCurrentMonth && modelData === String(root.today.getDate())

                Layout.fillWidth: true
                implicitHeight: day.implicitHeight + 2
                color: isToday ? Colors.fg : "transparent"

                Label {
                    id: day

                    anchors.centerIn: parent
                    text: parent.modelData
                    color: parent.isToday ? Colors.bg : Colors.fg
                }
            }
        }
    }

    Label {
        Layout.alignment: Qt.AlignHCenter
        text: `week ${root.weekNumber()} · ${Qt.formatTime(root.today, "hh:mm:ss")}`
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    // ISO-8601 week number
    function weekNumber(): int {
        const d = new Date(Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()));
        const day = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }
}
