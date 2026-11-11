import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings -> Updates and kawt: the version, updates, stripes, the ai, the tour and the keys
ColumnLayout {
    id: page

    required property ShellScreen forScreen

    spacing: 10

    PageHead {
        title: Strings.t("pageKawt")
        note: Strings.t("kawtNote")
    }

    Group {
        title: Strings.t("updates")

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Update.repo ? `${Update.repo.replace(Quickshell.env("HOME"), "~")} · ${Update.version}` : Strings.t("notGit")
            }

            // asks the remote once: nothing else of kawt's goes out by itself
            PushButton {
                visible: Update.repo !== ""
                text: Update.checking ? "…" : Strings.t("check")
                onClicked: Update.check(false)
            }

            // a terminal with ./install.sh --update: it shows what's new and asks first
            PushButton {
                visible: Update.repo !== ""
                text: Update.behind > 0 ? `${Strings.t("update")} (${Update.behind})…` : `${Strings.t("update")}…`
                onClicked: {
                    Update.run();
                    Panels.close();
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.WordWrap
            text: Update.status + (Update.news ? `: ${Update.news}` : "")
            color: Update.failed ? Colors.warn : Update.behind > 0 ? Colors.accent : Colors.dim
        }

        // one small request to github a week; off: nothing goes out unless "check" is pressed
        Check {
            Layout.fillWidth: true
            visible: Update.repo !== ""
            text: Strings.t("autoUpdate")
            note: Strings.t("autoUpdateNote")
            checked: Settings.updateAuto
            onToggled: Settings.updateAuto = !Settings.updateAuto
        }
    }

    Group {
        title: "stripes"

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Check {
                Layout.fillWidth: true
                text: Settings.companion ? `${Strings.t("companionOn")}: ${Companion.name}` : Strings.t("companionOn")
                note: Strings.t("companionNote")
                checked: Settings.companion
                onToggled: Settings.companion = !Settings.companion
            }

            PushButton {
                visible: Settings.companion
                text: Strings.t("herWindow")
                onClicked: Panels.toggle("home", page.forScreen ?? Quickshell.screens[0])
            }
        }
    }

    Group {
        title: Strings.t("ai")

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `${Ai.useApi ? "api" : "ollama"} · ${Ai.modelName}`
            }

            PushButton {
                text: Strings.t("aiSettings")
                onClicked: {
                    Panels.sidebarScreen = page.forScreen?.name ?? Panels.focusedScreen;
                    Panels.sidebarOpen = true;
                    Panels.aiTab = 3;
                    Panels.close();
                }
            }
        }

        Label {
            Layout.fillWidth: true
            text: Strings.t("aiHint")
            color: Colors.dim
        }
    }

    Group {
        title: Strings.t("helpGroup")

        RowLayout {
            spacing: 10

            // the first start's hello and short tour, again
            PushButton {
                text: Strings.t("tour")
                onClicked: Panels.toggle("welcome", page.forScreen ?? Quickshell.screens[0])
            }

            PushButton {
                text: Strings.t("allKeys")
                onClicked: Panels.toggle("keys", page.forScreen ?? Quickshell.screens[0])
            }
        }
    }

    Component.onCompleted: Ai.refresh()
}
