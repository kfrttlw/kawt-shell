import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings -> Keyboard and device: a layout per window, laptop or desktop
ColumnLayout {
    id: page

    required property ShellScreen forScreen

    spacing: 10

    PageHead {
        title: Strings.t("pageDevice")
        note: Strings.t("deviceNote")
    }

    Group {
        title: Strings.t("keyboardGroup")

        // services/Keyboard.qml: leaving a window remembers its layout, coming back puts it back
        Check {
            Layout.fillWidth: true
            enabled: Keyboard.count > 1
            text: Strings.t("perWindow")
            note: Keyboard.count < 2 ? Strings.t("oneLayout") : Settings.layoutPerWindow ? Strings.t("perWindowOn") : Strings.t("perWindowOff")
            checked: Settings.layoutPerWindow
            onToggled: if (Keyboard.count > 1)
                Settings.layoutPerWindow = !Settings.layoutPerWindow
        }
    }

    Group {
        title: Strings.t("deviceGroup")

        RowLayout {
            spacing: 14

            Repeater {
                model: ["auto", "laptop", "desktop"]

                Check {
                    required property string modelData

                    radio: true
                    text: modelData === "auto" ? `${Strings.t("auto")}: ${Strings.t(SysInfo.detectedLaptop ? "laptop" : "desktop")}` : Strings.t(modelData)
                    checked: Settings.device === modelData
                    onToggled: Settings.device = modelData
                }
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Strings.t("deviceWhat")
            color: Colors.dim
        }
    }
}
