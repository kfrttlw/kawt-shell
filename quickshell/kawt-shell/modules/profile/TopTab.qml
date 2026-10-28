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

ColumnLayout {
    required property var profile

    spacing: 0

    Label {
        Layout.topMargin: Metrics.spacing
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
