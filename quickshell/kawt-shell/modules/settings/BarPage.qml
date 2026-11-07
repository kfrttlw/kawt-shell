import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings -> Bar: where it is, what's on it. Switched off, a part still works on its key
ColumnLayout {
    id: page

    required property ShellScreen forScreen

    spacing: 10

    PageHead {
        title: Strings.t("pageBar")
        note: Strings.t("barNote")
    }

    Group {
        title: Strings.t("where")

        RowLayout {
            spacing: 14

            Check {
                radio: true
                text: Strings.t("top")
                checked: !Settings.barBottom
                onToggled: Settings.barBottom = false
            }

            Check {
                radio: true
                text: Strings.t("bottom")
                checked: Settings.barBottom
                onToggled: Settings.barBottom = true
            }

            Check {
                text: Strings.t("tuck")
                checked: Settings.barHidden
                onToggled: Settings.barHidden = !Settings.barHidden
            }

            Label {
                text: Strings.t("tuckNote")
                color: Colors.dim
            }
        }

        RowLayout {
            spacing: 14

            Label {
                text: Strings.t("height")
            }

            Repeater {
                model: [[0, Strings.t("auto")], [28, "28 px"], [32, "32 px"]]

                Check {
                    required property var modelData

                    radio: true
                    text: modelData[1]
                    checked: Settings.barHeight === modelData[0]
                    onToggled: Settings.barHeight = modelData[0]
                }
            }
        }
    }

    Group {
        title: Strings.t("leftSide")

        RowLayout {
            spacing: 14

            Check {
                text: Strings.t("quickLaunch")
                note: Strings.t("quickNote")
                checked: Settings.barShows("quick")
                onToggled: Settings.toggleBar("quick")
            }

            Check {
                text: Strings.t("deskNumbers")
                checked: Settings.barShows("workspaces")
                onToggled: Settings.toggleBar("workspaces")
            }
        }
    }

    Group {
        title: Strings.t("trayGroup")

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 20
            rowSpacing: 6

            Repeater {
                model: [
                    ["wifi", "wifi4", "net", ""],
                    ["vol", "vol2", "sound", ""],
                    ["bat", "bat8", "batteryOpt", "onlyLaptop"],
                    ["log", "bellDot", "notifs", ""],
                    ["kb", "", "layoutOpt", "ifMore"],
                    ["br", "sun", "brightness", "ifCan"],
                    ["mic", "mic", "micOpt", "whileUsed"],
                    ["bt", "bt", "bluetooth", "whileConnected"],
                    ["player", "note", "musicOpt", "whilePlays"],
                    ["tray", "", "appIcons", "behindArrow"],
                    ["clock", "", "clockOpt", ""],
                    ["vpn", "shield", "vpnOpt", "whileUp"]
                ]

                Check {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: modelData[1]
                    text: Strings.t(modelData[2])
                    note: modelData[3] ? Strings.t(modelData[3]) : ""
                    checked: Settings.barShows(modelData[0])
                    onToggled: Settings.toggleBar(modelData[0])
                }
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Strings.t("bySelf")
            color: Colors.dim
        }
    }

    Group {
        title: Strings.t("clockGroup")

        RowLayout {
            spacing: 14

            Check {
                radio: true
                text: "14:53"
                checked: Settings.clock24
                onToggled: Settings.clock24 = true
            }

            Check {
                radio: true
                text: "2:53 pm"
                checked: !Settings.clock24
                onToggled: Settings.clock24 = false
            }

            Check {
                text: Strings.t("seconds")
                checked: Settings.clockSeconds
                onToggled: Settings.clockSeconds = !Settings.clockSeconds
            }

            Check {
                text: Strings.t("date")
                checked: Settings.clockDate
                onToggled: Settings.clockDate = !Settings.clockDate
            }
        }
    }
}
