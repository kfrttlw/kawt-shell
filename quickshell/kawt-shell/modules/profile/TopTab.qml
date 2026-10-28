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

// The machine at work: cpu and memory over the last minute, then the busiest processes (a
// click twice: kill)
ColumnLayout {
    required property var profile

    spacing: 0

    // a titled box: ┌─cpu───── 42%┐
    component Card: TitledBox {
        id: card

        property bool warn: false
        default property alias content: cardBody.data

        Layout.fillWidth: true
        Layout.preferredWidth: 1 // equal widths
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: titleOverhang
        implicitHeight: cardBody.implicitHeight + Metrics.padding * 2 + titleOverhang
        border.color: warn ? Colors.warn : Colors.border

        ColumnLayout {
            id: cardBody

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + card.titleOverhang
            spacing: 4
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        spacing: Metrics.spacing

        Card {
            title: "cpu"
            hint: `${Math.round(SysInfo.cpu * 100)}%`
            warn: SysInfo.cpuTemp >= 85

            BarGraph {
                Layout.fillWidth: true
                values: SysInfo.cpuHistory.slice(profile.wide ? -40 : -24)
                barColor: SysInfo.cpuTemp >= 85 ? Colors.warn : Colors.fg
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: [SysInfo.cpuTemp >= 0 ? `${Math.round(SysInfo.cpuTemp)}°C` : "", SysInfo.fan > 0 ? `${SysInfo.fan} rpm` : SysInfo.fan === 0 ? "fan idle" : "", SysInfo.load ? `load ${SysInfo.load.split(" ")[0]}` : ""].filter(s => s).join(" · ")
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }
        }

        Card {
            title: "mem"
            hint: `${Math.round(SysInfo.mem * 100)}%`

            BarGraph {
                Layout.fillWidth: true
                values: SysInfo.memHistory.slice(profile.wide ? -40 : -24)
                barColor: Colors.fg
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `${SysInfo.memUsedGb.toFixed(1)}/${SysInfo.memTotalGb.toFixed(0)}G` + (SysInfo.swapTotalGb > 0 ? ` · swap ${(SysInfo.swap * SysInfo.swapTotalGb).toFixed(1)}G` : "")
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }
        }
    }

    Label {
        Layout.topMargin: Metrics.spacing * 2
        Layout.bottomMargin: Metrics.spacing
        text: `tasks ${SysInfo.taskCount} · cpu ${Math.round(SysInfo.cpu * 100)}% · load ${SysInfo.load}`
        color: Colors.dim
    }

    Label {
        text: "    PID  CPU%  MEM%  S  COMMAND"
        color: Colors.accent
    }

    Repeater {
        model: SysInfo.procs

        Item {
            id: proc

            required property var modelData
            readonly property bool armed: profile.armed === `kill:${modelData.pid}`

            Layout.fillWidth: true
            implicitHeight: procLine.implicitHeight

            Rectangle {
                anchors.fill: parent
                visible: procArea.containsMouse || proc.armed
                color: Colors.hoverFill
            }

            Label {
                id: procLine

                width: parent.width
                elide: Text.ElideRight
                text: proc.armed
                    ? `${String(proc.modelData.pid).padStart(7)}  kill ${proc.modelData.comm}? click again`
                    : `${String(proc.modelData.pid).padStart(7)} ${proc.modelData.cpu.toFixed(1).padStart(5)} ${proc.modelData.mem.toFixed(1).padStart(5)}  ${proc.modelData.state}  ${proc.modelData.comm}`
                color: proc.armed ? Colors.warn : proc.modelData.cpu >= 50 ? Colors.accent : Colors.fg
            }

            MouseArea {
                id: procArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (proc.armed) {
                        profile.armed = "";
                        SysInfo.kill(proc.modelData.pid);
                    } else {
                        profile.armed = `kill:${proc.modelData.pid}`;
                        disarm.restart();
                    }
                }
            }
        }
    }

    Label {
        Layout.topMargin: Metrics.spacing
        Layout.alignment: Qt.AlignRight
        text: "click twice: kill (SIGTERM)"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 3
    }
}
