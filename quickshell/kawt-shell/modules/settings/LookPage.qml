import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings -> Look: the theme (light or dark), the font, the language, the effects, the profile's
// header. Everything changes at once, no restart
ColumnLayout {
    id: page

    required property ShellScreen forScreen

    spacing: 10

    PageHead {
        title: Strings.t("pageLook")
        note: Strings.t("lookNote")
    }

    Group {
        title: Strings.t("theme")

        // a small window in each theme's colors, the one in use picked
        Flow {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: Colors.choices

                Item {
                    id: card

                    required property var modelData
                    readonly property var pal: (Colors.themes[modelData.theme] || {})[modelData.light === null ? Colors.variant : modelData.light ? "light" : "dark"] ?? {}
                    readonly property bool picked: Colors.isCurrent(modelData)
                    readonly property string shownName: modelData.name === "black" ? Strings.t("graphite") : modelData.name === "white" ? Strings.t("silver") : modelData.name === "wallpaper" ? Strings.t("fromWallpaper") : modelData.name

                    width: 140
                    height: 96

                    Rectangle {
                        width: parent.width
                        height: 70
                        color: card.pal.bg ?? Colors.bg
                        border.color: card.picked ? Colors.accent : Colors.lo
                        border.width: card.picked ? 2 : 1

                        // the little window
                        Rectangle {
                            x: 14
                            y: 12
                            width: parent.width - 28
                            height: parent.height - 24
                            color: card.pal.face ?? card.pal.bg ?? Colors.face
                            border.color: card.pal.deep ?? "#000000"

                            Rectangle {
                                x: 2
                                y: 2
                                width: parent.width - 4
                                height: 8
                                color: card.pal.title ?? card.pal.fg ?? "#000000"

                                Rectangle {
                                    x: 2
                                    y: 1
                                    width: 3
                                    height: 6
                                    color: card.pal.accent ?? Colors.accent
                                }
                            }

                            Rectangle {
                                x: 6
                                y: 16
                                width: parent.width - 30
                                height: 6
                                color: card.pal.field ?? card.pal.bg ?? Colors.well
                            }
                        }
                    }

                    Check {
                        y: 76
                        anchors.horizontalCenter: parent.horizontalCenter
                        radio: true
                        checked: card.picked
                        text: card.shownName
                        onToggled: Colors.choose(card.modelData)
                    }

                    MouseArea {
                        width: parent.width
                        height: 70
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Colors.choose(card.modelData)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Check {
                radio: true
                text: Strings.t("lightV")
                checked: Settings.light
                onToggled: Settings.light = true
            }

            Check {
                radio: true
                text: Strings.t("darkV")
                checked: !Settings.light
                onToggled: Settings.light = false
            }

            Label {
                Layout.fillWidth: true
                text: Strings.t("lightKey")
                color: Colors.dim
                elide: Text.ElideRight
            }

            PushButton {
                text: Strings.t("ownTheme")
                onClicked: {
                    Panels.styleEdit = "new";
                    Panels.toggle("style", page.forScreen);
                }
            }
        }
    }

    Group {
        title: Strings.t("font")

        RowLayout {
            spacing: 14

            Repeater {
                model: [["Departure Mono", "Departure Mono"], ["BlexMono Nerd Font Mono", "IBM Plex Mono"]].filter(f => f[0] === "Departure Mono" || Qt.fontFamilies().includes(f[0]))

                Check {
                    required property var modelData

                    radio: true
                    text: modelData[1]
                    checked: Settings.fontFamily === modelData[0] || (modelData[0] !== "Departure Mono" && Metrics.fontFamily === modelData[0])
                    onToggled: {
                        Settings.fontFamily = modelData[0];
                        Settings.fontSize = modelData[0] === "Departure Mono" ? 11 : 13;
                    }
                }
            }

            Label {
                text: "·"
                color: Colors.dim
            }

            Repeater {
                model: Metrics.pixel ? [11, 22] : [11, 12, 13, 14, 16]

                Check {
                    required property int modelData

                    radio: true
                    text: `${modelData} px`
                    checked: Metrics.fontSize === modelData
                    onToggled: Settings.fontSize = modelData
                }
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Metrics.pixel ? Strings.t("pixelNote") : Strings.t("smoothNote")
            color: Colors.dim
        }

        // another one, by the name fc-list gives it
        TermInput {
            Layout.fillWidth: true
            prompt: "font>"
            text: Settings.fontFamily
            placeholder: Strings.t("fontOther")
            onAccepted: t => Settings.fontFamily = t.trim() || "Departure Mono"
        }
    }

    Group {
        title: Strings.t("language")

        RowLayout {
            spacing: 14

            Check {
                radio: true
                text: "English"
                checked: !Strings.ru
                onToggled: Settings.language = "en"
            }

            Check {
                radio: true
                text: "Русский"
                checked: Strings.ru
                onToggled: Settings.language = "ru"
            }
        }
    }

    Group {
        title: Strings.t("effects")

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 20
            rowSpacing: 8

            Check {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: Strings.t("bootScreen")
                note: Strings.t("bootNote")
                checked: Settings.bootScreen
                onToggled: Settings.bootScreen = !Settings.bootScreen
            }

            Check {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: Strings.t("crtLock")
                note: Strings.t("crtNote")
                checked: Settings.crt
                onToggled: Settings.crt = !Settings.crt
            }

            Check {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: Strings.t("scanlines")
                note: Strings.t("scanNote")
                checked: Settings.scanlines
                onToggled: Settings.scanlines = !Settings.scanlines
            }

            Check {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: Strings.t("oldMachine")
                note: Strings.t("oldNote")
                checked: Settings.lite
                onToggled: Settings.lite = !Settings.lite
            }
        }
    }

    Group {
        title: Strings.t("profileHead")

        TermInput {
            Layout.fillWidth: true
            prompt: "motto>"
            text: Settings.motto
            placeholder: "stay curious"
            onAccepted: t => Settings.motto = t.trim()
        }

        RowLayout {
            spacing: 14

            Check {
                radio: true
                text: Strings.t("faceAscii")
                checked: Settings.profileArt === "auto"
                onToggled: Settings.profileArt = "auto"
            }

            Check {
                radio: true
                text: Strings.t("kawtLogo")
                checked: Settings.profileArt === "machine"
                onToggled: Settings.profileArt = "machine"
            }
        }
    }
}
