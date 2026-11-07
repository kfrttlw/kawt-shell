import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// The week's focus, the old way: a sunk column a day, a block a round (as many blocks as the
// goal, or the rounds if there were more), today's red; the day's name under it. Today and the
// focus tab show it.
//   week  ▯ ▯ ▯ ▯ ▯ ▯ ▯
//         mon tue wed thu fri sat sun                      streak: 4 days
RowLayout {
    id: root

    property bool streak: true // the days in a row with something done, on the right
    readonly property var locale: Qt.locale(Strings.ru ? "ru_RU" : "en_US")

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
                text: root.locale.toString(day.modelData.date, "ddd").toLowerCase()
                color: day.modelData.isToday ? Colors.accent : Colors.dim
            }
        }
    }

    Item {
        Layout.fillWidth: true
    }

    Label {
        Layout.alignment: Qt.AlignBottom
        visible: root.streak && Todo.streak > 0
        text: Strings.t("streakIs").arg(Strings.count(Todo.streak, "day"))
        color: Colors.dim
    }
}
