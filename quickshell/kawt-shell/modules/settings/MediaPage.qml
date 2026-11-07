import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings -> Sound and media: screenshots, recordings, the player
ColumnLayout {
    id: page

    required property ShellScreen forScreen

    spacing: 10

    PageHead {
        title: Strings.t("pageMedia")
        note: Strings.t("mediaNote")
    }

    Group {
        title: Strings.t("shotsGroup")

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Strings.t("shotsKeys")
            color: Colors.dim
        }

        TermInput {
            Layout.fillWidth: true
            prompt: "dir>"
            text: Settings.screenshotDir
            onAccepted: t => Settings.screenshotDir = t.trim() || Settings.screenshotDir
        }

        RowLayout {
            spacing: 20

            Check {
                text: Strings.t("shotAsk")
                note: Strings.t("shotAskNote")
                checked: Settings.screenshotAsk
                onToggled: Settings.screenshotAsk = !Settings.screenshotAsk
            }

            // the screen stands still while an area is picked (hyprpicker)
            Check {
                visible: Screenshot.canFreeze
                text: Strings.t("shotFreeze")
                note: Strings.t("shotFreezeNote")
                checked: Settings.screenshotFreeze
                onToggled: Settings.screenshotFreeze = !Settings.screenshotFreeze
            }
        }
    }

    Group {
        title: Strings.t("recGroup")

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Strings.t("recKeys")
            color: Colors.dim
        }

        TermInput {
            Layout.fillWidth: true
            prompt: "dir>"
            text: Settings.recordDir
            onAccepted: t => Settings.recordDir = t.trim() || Settings.recordDir
        }

        RowLayout {
            spacing: 14

            Label {
                text: Strings.t("recSound")
            }

            Repeater {
                model: [["off", Strings.t("none")], ["mic", Strings.t("micOpt")], ["system", Strings.t("whatYouHear")], ["both", Strings.t("both")]]

                Check {
                    required property var modelData

                    radio: true
                    text: modelData[1]
                    checked: Recorder.sound === modelData[0]
                    onToggled: Settings.recordSound = modelData[0]
                }
            }
        }
    }

    Group {
        title: Strings.t("playerGroup")

        // spotify's covers are on its servers; the local ones (firefox, mpv) always show
        Check {
            Layout.fillWidth: true
            text: Strings.t("netCovers")
            note: Strings.t("netCoversNote")
            checked: Settings.playerNetCovers
            onToggled: Settings.playerNetCovers = !Settings.playerNetCovers
        }
    }
}
