import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings -> Screen and lock: what the lock shows, when it locks by itself, the screen going off,
// the night light
ColumnLayout {
    id: page

    required property ShellScreen forScreen

    spacing: 10

    PageHead {
        title: Strings.t("pageScreen")
        note: Strings.t("screenNote")
    }

    Group {
        title: Strings.t("lockGroup")

        Check {
            Layout.fillWidth: true
            text: Strings.t("lockDetails")
            note: Strings.t("lockDetailsNote")
            checked: Settings.lockDetails
            onToggled: Settings.lockDetails = !Settings.lockDetails
        }

        // services/Session.qml: the lid, systemctl suspend, loginctl lock-session
        Check {
            Layout.fillWidth: true
            visible: Session.available
            text: Strings.t("lockSleep")
            note: Strings.t("lockSleepNote")
            checked: Settings.lockOnSleep
            onToggled: Settings.lockOnSleep = !Settings.lockOnSleep
        }
    }

    Group {
        title: Strings.t("idleGroup")

        RowLayout {
            spacing: 14

            Repeater {
                model: [[0, Strings.t("never")], [5, "5 min"], [10, "10 min"], [30, "30 min"]]

                Check {
                    required property var modelData

                    radio: true
                    text: modelData[1]
                    checked: Settings.idleLock === modelData[0]
                    onToggled: Settings.idleLock = modelData[0]
                }
            }

            // any other time, in minutes (0 = off)
            TermInput {
                id: idleInput

                readonly property bool custom: ![0, 5, 10, 30].includes(Settings.idleLock)

                Layout.preferredWidth: 180
                prompt: "min>"
                placeholder: custom ? `${Settings.idleLock} min` : Strings.t("other")
                onAccepted: t => {
                    const m = parseInt(t);
                    if (/^\s*\d+\s*$/.test(t) && m <= 1440) {
                        Settings.idleLock = m;
                        idleInput.text = "";
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Idle.caffeine ? Strings.t("idleCaf") : Settings.idleLock === 0 ? Strings.t("idleNever") : Strings.t("idleAfter").arg(Settings.idleLock)
            color: Idle.caffeine ? Colors.accent : Colors.dim
        }

        RowLayout {
            spacing: 14

            Label {
                text: Strings.t("screenOff")
            }

            Repeater {
                model: [[0, Strings.t("never")], [1, "1 min"], [2, "2 min"], [5, "5 min"]]

                Check {
                    required property var modelData

                    radio: true
                    text: modelData[1]
                    checked: Settings.screenOff === modelData[0]
                    onToggled: Settings.screenOff = modelData[0]
                }
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Settings.screenOff > 0 ? Strings.t("screenOffNote").arg(Settings.screenOff) : Strings.t("screenStays")
            color: Colors.dim
        }

        // laptops: the backlight down to a third, 30 s before the idle lock
        Check {
            Layout.fillWidth: true
            visible: Brightness.available && Settings.idleLock > 0
            text: Strings.t("dimBefore")
            note: Strings.t("dimBeforeNote")
            checked: Settings.dimBeforeLock
            onToggled: Settings.dimBeforeLock = !Settings.dimBeforeLock
        }
    }

    // hyprsunset
    Group {
        visible: Night.available
        title: Strings.t("nightGroup")

        RowLayout {
            spacing: 10

            Check {
                text: Strings.t("nightOn")
                checked: Settings.nightLight
                onToggled: Settings.nightLight = !Settings.nightLight
            }

            Label {
                text: `${Night.temp}K`
                color: Settings.nightLight ? Colors.fg : Colors.dim
            }

            PushButton {
                text: Strings.t("warmer")
                onClicked: Night.warmer()
            }

            PushButton {
                text: Strings.t("cooler")
                onClicked: Night.cooler()
            }
        }
    }
}
