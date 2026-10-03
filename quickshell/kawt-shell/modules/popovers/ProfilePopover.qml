import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils

Popover {
    id: root

    property string armed: "" // power action waiting for a second click

    name: "profile"
    title: `${SysInfo.user}@${SysInfo.host}`
    cardWidth: 560

    function power(action: string, cmd: list<string>): void {
        if (action === "lock" || action === "sleep" || armed === action) {
            armed = "";
            Panels.close();
            if (action === "lock")
                Panels.locked = true;
            else if (action === "logout")
                Hypr.exit();
            else
                Quickshell.execDetached(cmd);
        } else {
            armed = action;
            disarm.restart();
        }
    }

    onOpenChanged: if (!open)
        armed = ""

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    Tabs {
        id: tabs

        tabs: ["sys", "top", "notes", "cfg"]
    }

    // the process list is only sampled while its tab is on screen
    Binding {
        target: SysInfo
        property: "topActive"
        value: tabs.current === 1
        when: root.open
    }

    // ---------------------------------------------------------------- sys
    ColumnLayout {
        Layout.fillWidth: true
        visible: tabs.current === 0
        spacing: Metrics.spacing

        RowLayout {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            spacing: Metrics.padding * 2

            DeviceArt {
                Layout.alignment: Qt.AlignTop
                laptop: SysInfo.laptop
                blink: root.open
            }

            // neofetch-style facts; empty ones are skipped
            Column {
                Layout.fillWidth: true
                Layout.preferredWidth: 0 // take the leftover width, don't size from the (elided) text
                Layout.alignment: Qt.AlignTop

                Label {
                    text: `${SysInfo.user}@${SysInfo.host}`
                    color: Colors.accent
                }

                Label {
                    text: "-".repeat(`${SysInfo.user}@${SysInfo.host}`.length)
                    color: Colors.dim
                }

                Repeater {
                    model: [
                        ["os", SysInfo.os],
                        ["host", SysInfo.model.replace(/^ThinkPad /, "tp ")],
                        ["kern", SysInfo.kernel],
                        ["up", Fmt.uptime(SysInfo.uptime)],
                        ["pkgs", SysInfo.pkgs > 0 ? String(SysInfo.pkgs) : ""],
                        ["shell", SysInfo.shell],
                        ["wm", SysInfo.wm],
                        ["cpu", SysInfo.cpuModel + (SysInfo.cores > 0 ? ` (${SysInfo.cores})` : "")],
                        ...SysInfo.gpus.map(g => ["gpu", g]),
                        ["res", SysInfo.res]
                    ].filter(r => r[1])

                    Row {
                        required property var modelData

                        width: parent.width

                        Label {
                            width: Metrics.fontSize * 0.6 * 6
                            text: modelData[0]
                            color: Colors.dim
                        }

                        Label {
                            width: parent.width - x
                            elide: Text.ElideRight
                            text: modelData[1]
                        }
                    }
                }
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            clip: true
            text: "-- load " + "-".repeat(80)
            color: Colors.border
        }

        Meter {
            name: "cpu"
            value: SysInfo.cpu
            extra: SysInfo.cpuTemp >= 0 ? `${Math.round(SysInfo.cpuTemp)}°C` : ""
            history: SysInfo.cpuHistory
            warn: SysInfo.cpuTemp >= 85
        }

        Meter {
            name: "mem"
            value: SysInfo.mem
            extra: `${SysInfo.memUsedGb.toFixed(1)}/${SysInfo.memTotalGb.toFixed(0)}G`
            history: SysInfo.memHistory
        }

        Meter {
            visible: SysInfo.swapTotalGb > 0
            name: "swp"
            value: SysInfo.swap
            extra: `${(SysInfo.swap * SysInfo.swapTotalGb).toFixed(1)}/${SysInfo.swapTotalGb.toFixed(0)}G`
        }

        Meter {
            name: "dsk"
            value: SysInfo.disk
            extra: "/"
            warn: SysInfo.disk >= 0.9
        }

        Meter {
            readonly property var dev: UPower.displayDevice
            readonly property bool charging: dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged

            visible: dev.isLaptopBattery
            name: "bat"
            value: dev.percentage
            suffix: charging ? "+" : ""
            extra: [
                !charging && dev.timeToEmpty > 0 ? Fmt.uptime(dev.timeToEmpty) : "",
                Math.abs(dev.changeRate) >= 0.1 ? `${dev.changeRate.toFixed(1)}W` : "",
                SysInfo.batHealth > 0 ? `health ${Math.round(SysInfo.batHealth * 100)}%` : "",
                SysInfo.batCycles > 0 ? `${SysInfo.batCycles}cyc` : "",
                SysInfo.batLimit > 0 && SysInfo.batLimit < 100 ? `stop@${SysInfo.batLimit}%` : ""
            ].filter(s => s).join(" · ")
            warn: !charging && dev.percentage < 0.15
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: [
                SysInfo.fan >= 0 ? `fan ${SysInfo.fan > 0 ? SysInfo.fan + " rpm" : "idle"}` : "",
                SysInfo.load ? `load ${SysInfo.load}` : ""
            ].filter(s => s).join(" · ")
            color: Colors.dim
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Metrics.borderWidth
            color: Colors.border
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Metrics.spacing

            BracketButton {
                label: "lock"
                onClicked: root.power("lock", [])
            }

            BracketButton {
                label: "sleep"
                onClicked: root.power("sleep", ["systemctl", "suspend"])
            }

            BracketButton {
                label: root.armed === "logout" ? "sure?" : "logout"
                textColor: root.armed === "logout" ? Colors.warn : Colors.fg
                onClicked: root.power("logout", [])
            }

            BracketButton {
                label: root.armed === "reboot" ? "sure?" : "reboot"
                textColor: root.armed === "reboot" ? Colors.warn : Colors.fg
                onClicked: root.power("reboot", ["systemctl", "reboot"])
            }

            BracketButton {
                label: root.armed === "off" ? "sure?" : "off"
                textColor: root.armed === "off" ? Colors.warn : Colors.fg
                onClicked: root.power("off", ["systemctl", "poweroff"])
            }
        }
    }

    // ---------------------------------------------------------------- top
    ColumnLayout {
        Layout.fillWidth: true
        visible: tabs.current === 1
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
                readonly property bool armed: root.armed === `kill:${modelData.pid}`

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
                            root.armed = "";
                            SysInfo.kill(proc.modelData.pid);
                        } else {
                            root.armed = `kill:${proc.modelData.pid}`;
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

    // cpu [########------------]  42%  54°C  ▁▂▃▅▇▆▃▂
    component Meter: RowLayout {
        id: meter

        property string name
        property real value
        property string suffix
        property string extra
        property var history: []
        property bool warn: false

        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            text: `${meter.name} [${Fmt.bar(meter.value, 20)}] ${String(Math.round(meter.value * 100)).padStart(3)}%${meter.suffix}`
            color: meter.warn ? Colors.warn : Colors.fg
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: meter.extra
            color: Colors.dim
        }

        Label {
            visible: meter.history.length > 0
            text: Fmt.spark(meter.history.slice(-16))
            color: Colors.accent
        }
    }

    // -------------------------------------------------------------- notes
    ColumnLayout {
        Layout.fillWidth: true
        visible: tabs.current === 2
        spacing: 2

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            implicitHeight: 240
            color: Colors.hoverFill
            border.color: notes.activeFocus ? Colors.dim : Colors.border
            border.width: Metrics.borderWidth

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.margins: Metrics.spacing
                clip: true
                contentHeight: notes.contentHeight
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: notes

                    width: flick.width
                    color: Colors.fg
                    font.family: Metrics.fontFamily
                    font.pixelSize: Metrics.fontSize
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.bg
                    cursorDelegate: BlockCursor {
                        visible: notes.activeFocus
                    }

                    Component.onCompleted: text = Notes.text
                    onTextChanged: Notes.set(text)
                    // keep the cursor in view while typing
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < flick.contentY)
                            flick.contentY = cursorRectangle.y;
                        else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                            flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
                    }

                    Label {
                        visible: !notes.text && !notes.activeFocus
                        text: "# todo\n- ..."
                        color: Colors.dim
                    }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignRight
            text: `-- ${notes.lineCount} lines · ~/.local/state/kawt/notes.txt --`
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
        }
    }

    // ---------------------------------------------------------------- cfg
    ColumnLayout {
        Layout.fillWidth: true
        visible: tabs.current === 3
        spacing: Metrics.spacing
        onVisibleChanged: if (visible)
            Ai.checkStatus()

        RowLayout {
            Layout.topMargin: Metrics.spacing
            spacing: Metrics.spacing

            Label {
                text: `theme: ${Colors.fullName}`
                color: Colors.dim
            }

            BracketButton {
                label: "wallpaper & themes"
                textColor: Colors.accent
                onClicked: Panels.toggle("style", root.forScreen)
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            text: "device"
            color: Colors.dim
        }

        Flow {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Repeater {
                model: ["auto", "laptop", "desktop"]

                BracketButton {
                    required property string modelData

                    label: modelData === "auto" ? `auto: ${SysInfo.detectedLaptop ? "laptop" : "desktop"}` : modelData
                    active: Settings.device === modelData
                    onClicked: Settings.device = modelData
                }
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            text: Ai.online ? "ollama model" : "ollama model (offline)"
            color: Colors.dim
        }

        // pulled models
        Flow {
            Layout.fillWidth: true
            visible: Ai.models.length > 0
            spacing: Metrics.spacing

            Repeater {
                model: Ai.models

                BracketButton {
                    required property string modelData

                    label: modelData.replace(/:latest$/, "")
                    active: Settings.ollamaModel === modelData || Settings.ollamaModel + ":latest" === modelData
                    onClicked: Settings.ollamaModel = modelData
                }
            }
        }

        TermInput {
            Layout.fillWidth: true
            prompt: "$"
            text: Settings.ollamaModel
            onAccepted: t => Settings.ollamaModel = t.trim() || Settings.ollamaModel
        }

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "[?] hyprland binds: see hypr/kawt.lua in the config folder\n[?] in the ai panel: /model <name>, /models"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }
}
