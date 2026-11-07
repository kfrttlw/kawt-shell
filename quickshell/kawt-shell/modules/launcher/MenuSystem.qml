import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.utils
import "../profile"

// The start menu's system: the machine at work. The last minute of cpu and memory as bars in
// sunk wells, the net now, then the busiest programs (a click twice: kill, as in the profile's
// top tab). Sampled only while the menu is open (services/SysInfo.qml), the programs only while
// this is shown.
ColumnLayout {
    id: root

    property int armed: 0 // the pid a first click asked to kill

    spacing: Metrics.spacing

    Component.onCompleted: SysInfo.topActive = true
    Component.onDestruction: SysInfo.topActive = false

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = 0
    }

    // a line of what it is above its graph: cpu 12% ........ 54°C · 2400 rpm
    component Head: RowLayout {
        property string what: ""
        property string value: ""
        property string more: ""

        Layout.fillWidth: true

        Label {
            text: parent.what
            color: Colors.dim
        }

        Label {
            text: parent.value
            font.bold: true
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: parent.more
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing * 2

        Label {
            text: SysInfo.host || "kawt"
            font.bold: true
            font.pixelSize: Metrics.fontSize + 2
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: [SysInfo.os, SysInfo.kernel, `up ${Fmt.uptime(SysInfo.uptime)}`].filter(s => s).join(" · ")
            color: Colors.dim
        }
    }

    Head {
        what: "cpu"
        value: `${Math.round(SysInfo.cpu * 100)}%`
        more: [SysInfo.cpuTemp >= 0 ? `${Math.round(SysInfo.cpuTemp)}°C` : "", SysInfo.fan > 0 ? `${SysInfo.fan} rpm` : "", SysInfo.load ? `load ${SysInfo.load.split(" ")[0]}` : ""].filter(s => s).join(" · ")
    }

    Well {
        Layout.fillWidth: true
        implicitHeight: Math.round(Metrics.fontSize * 3.6)

        BarGraph {
            anchors.fill: parent
            anchors.margins: 4
            values: SysInfo.cpuHistory
            barColor: SysInfo.cpuTemp >= 85 ? Colors.warn : Colors.accent
        }
    }

    Head {
        what: "memory"
        value: `${SysInfo.memUsedGb.toFixed(1)} of ${SysInfo.memTotalGb.toFixed(0)} GB`
        more: SysInfo.swapTotalGb > 0 ? `swap ${(SysInfo.swap * SysInfo.swapTotalGb).toFixed(1)} GB` : ""
    }

    Well {
        Layout.fillWidth: true
        implicitHeight: Math.round(Metrics.fontSize * 1.8)

        BarGraph {
            anchors.fill: parent
            anchors.margins: 4
            values: SysInfo.memHistory
            barColor: Colors.fg
        }
    }

    Head {
        what: "net"
        value: `↓ ${Fmt.rate(NetStats.rx).trim()}  ↑ ${Fmt.rate(NetStats.tx).trim()}`
        more: `disk ${Math.round(SysInfo.disk * 100)}%`
    }

    // the busiest programs
    Well {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Column {
            anchors.fill: parent
            anchors.margins: 3
            clip: true

            Repeater {
                model: SysInfo.procs.slice(0, 6)

                Item {
                    id: proc

                    required property var modelData
                    readonly property bool armed: root.armed === modelData.pid

                    width: parent.width
                    height: Metrics.fontSize + 8

                    Rectangle {
                        anchors.fill: parent
                        visible: area.containsMouse || proc.armed
                        color: proc.armed && Colors.bevel ? Colors.accent : Colors.hoverFill
                    }

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Metrics.spacing
                        anchors.right: load.left
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: proc.armed ? `kill ${proc.modelData.comm}? click again` : proc.modelData.comm
                        color: proc.armed ? (Colors.bevel ? Colors.onAccent : Colors.warn) : Colors.fg
                    }

                    Label {
                        id: load

                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${proc.modelData.cpu.toFixed(1).padStart(5)}%  ${proc.modelData.mem.toFixed(1).padStart(4)}%`
                        color: proc.armed && Colors.bevel ? Colors.onAccent : proc.modelData.cpu >= 50 ? Colors.accent : Colors.dim
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (proc.armed) {
                                root.armed = 0;
                                SysInfo.kill(proc.modelData.pid);
                            } else {
                                root.armed = proc.modelData.pid;
                                disarm.restart();
                            }
                        }
                    }
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: SysInfo.procs.length === 0
            text: "..."
            color: Colors.dim
        }
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: "cpu  mem · a click twice: kill (SIGTERM) · more: the profile's top"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }
}
