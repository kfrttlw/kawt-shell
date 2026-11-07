import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// The machine at work, as an old task manager had it: cpu and memory over the last minute in
// two group boxes, then the busiest processes in a table. A click picks one, End process (twice)
// sends it SIGTERM; a double click on it does the same as the first press.
ColumnLayout {
    id: tab

    required property var profile
    property int picked: 0 // the pid
    property bool armed: false
    readonly property int rowHeight: Metrics.fontSize + 7
    readonly property var pickedProc: SysInfo.procs.find(p => p.pid === picked) ?? null
    // the table's columns: pid, cpu, mem, state, then the command
    readonly property var cols: [Metrics.fontSize * 0.6 * 9, Metrics.fontSize * 0.6 * 7, Metrics.fontSize * 0.6 * 7, Metrics.fontSize * 0.6 * 4]

    spacing: Metrics.spacing

    Timer {
        id: disarm

        interval: 3000
        onTriggered: tab.armed = false
    }

    // cpu and memory: a box each, the graph sunk in it
    component Meter: Group {
        id: meter

        property var values: []
        property bool hot: false
        property string line: ""

        Layout.preferredWidth: 1 // equal widths
        Layout.alignment: Qt.AlignTop

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            color: Colors.well

            Bevel {
                style: "sunk"
            }

            BarGraph {
                anchors.fill: parent
                anchors.margins: 3
                values: meter.values
                barColor: meter.hot ? Colors.warn : Colors.accent
            }
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: meter.line
            color: Colors.dim
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        spacing: Metrics.padding

        Meter {
            title: `CPU · ${Math.round(SysInfo.cpu * 100)}%`
            values: SysInfo.cpuHistory.slice(tab.profile.wide ? -40 : -24)
            hot: SysInfo.cpuTemp >= 85
            line: [SysInfo.cpuTemp >= 0 ? `${Math.round(SysInfo.cpuTemp)}°C` : "", SysInfo.fan > 0 ? `${SysInfo.fan} rpm` : SysInfo.fan === 0 ? Strings.t("topFanIdle") : "", SysInfo.load ? `${Strings.t("topLoad")} ${SysInfo.load.split(" ")[0]}` : ""].filter(s => s).join(" · ")
        }

        Meter {
            title: `${Strings.t("memory").replace(/^./, c => c.toUpperCase())} · ${Math.round(SysInfo.mem * 100)}%`
            values: SysInfo.memHistory.slice(tab.profile.wide ? -40 : -24)
            line: `${SysInfo.memUsedGb.toFixed(1)} / ${SysInfo.memTotalGb.toFixed(0)}G` + (SysInfo.swapTotalGb > 0 ? ` · swap ${(SysInfo.swap * SysInfo.swapTotalGb).toFixed(1)}G` : "")
        }
    }

    // the table: raised column heads over a sunk list
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: heads.height + tab.rowHeight * 11 + 4
        color: Colors.well

        Bevel {
            style: "sunk"
        }

        Row {
            id: heads

            x: 2
            y: 2
            width: parent.width - 4

            Repeater {
                model: ["PID", "CPU%", "MEM%", "S", Strings.t("topCommand")]

                Rectangle {
                    required property string modelData
                    required property int index

                    width: index < 4 ? tab.cols[index] : heads.width - tab.cols.reduce((a, b) => a + b, 0)
                    height: tab.rowHeight + 2
                    color: Colors.face

                    Bevel {
                        style: "raised"
                    }

                    Label {
                        x: 5
                        width: parent.width - 9
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: index > 0 && index < 3 ? Text.AlignRight : Text.AlignLeft
                        elide: Text.ElideRight
                        text: modelData
                    }
                }
            }
        }

        Flickable {
            x: 2
            y: heads.y + heads.height
            width: parent.width - 4
            height: parent.height - y - 2
            clip: true
            contentHeight: procs.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: procs

                width: parent.width

                Repeater {
                    model: SysInfo.procs

                    Rectangle {
                        id: proc

                        required property var modelData
                        readonly property bool on: modelData.pid === tab.picked
                        readonly property color ink: on ? Colors.onAccent : modelData.cpu >= 50 ? Colors.accent : Colors.fg

                        width: procs.width
                        height: tab.rowHeight
                        color: on ? Colors.accent : procArea.containsMouse ? Colors.hoverFill : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: [String(proc.modelData.pid), proc.modelData.cpu.toFixed(1), proc.modelData.mem.toFixed(1), proc.modelData.state, proc.modelData.comm]

                                Label {
                                    required property string modelData
                                    required property int index

                                    width: index < 4 ? tab.cols[index] : procs.width - tab.cols.reduce((a, b) => a + b, 0)
                                    leftPadding: 5
                                    rightPadding: 4
                                    horizontalAlignment: index > 0 && index < 3 ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    text: modelData
                                    color: proc.ink
                                }
                            }
                        }

                        MouseArea {
                            id: procArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tab.picked !== proc.modelData.pid)
                                    tab.armed = false;
                                tab.picked = proc.modelData.pid;
                            }
                            onDoubleClicked: {
                                tab.picked = proc.modelData.pid;
                                tab.armed = true;
                                disarm.restart();
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: tab.armed && tab.pickedProc ? Strings.t("topSure").arg(tab.pickedProc.comm) : Strings.t("topLine").arg(SysInfo.taskCount).arg(SysInfo.load)
            color: tab.armed ? Colors.warn : Colors.dim
        }

        // twice: SIGTERM
        PushButton {
            enabled: tab.pickedProc !== null
            text: tab.armed ? Strings.t("sureAgain") : Strings.t("topEnd")
            onClicked: {
                if (tab.armed) {
                    tab.armed = false;
                    SysInfo.kill(tab.picked);
                    tab.picked = 0;
                } else {
                    tab.armed = true;
                    disarm.restart();
                }
            }
        }
    }
}
