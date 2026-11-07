import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// stripes' window (super + h on her, the start menu's "stripes"). The switch on top turns her
// off. Tabs:
//   her    she herself; her look, whether an empty desktop is hers, a pomodoro, sleep, her name
//   talk   the language she speaks, your own phrases for her, wise words
Popover {
    id: root

    name: "home"
    title: Companion.name
    icon: "stripes"
    cardWidth: 340
    settingsPage: "kawt"
    note: Strings.t("herNote")
    switchText: Strings.t("micOn")
    switchOn: Settings.companion
    // off: she stops walking and peeking, nothing runs for her (on again in settings -> kawt)
    onSwitchToggled: {
        Panels.close();
        Settings.companion = false;
    }

    readonly property int tab: tabs.current

    // "3 days together"
    function together(): string {
        const d = Math.floor((Companion.now - (Companion.born || Companion.now)) / 86400000);
        return d < 1 ? Strings.t("herMetToday") : Strings.t("herTogether").arg(Strings.count(d, "day"));
    }

    onCardKey: event => {
        if (event.key === Qt.Key_Tab) {
            tabs.current = (tabs.current + 1) % 2;
            event.accepted = true;
        }
    }

    Tabs {
        id: tabs

        tabs: [Strings.t("herTab"), Strings.t("herTalkTab")]
    }

    // ------------------------------------------------------------ her
    // her place: she stands at the bottom, what she says over her
    Rectangle {
        id: stage

        Layout.fillWidth: true
        Layout.topMargin: -Metrics.spacing
        Layout.preferredHeight: Math.round(210 * Metrics.scale)
        visible: root.tab === 0
        color: Colors.well
        clip: true

        Bevel {
            style: "sunk"
        }
        Her {
            id: her

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            size: Math.round(180 * Metrics.scale)
            forScreen: root.forScreen
            origin: Qt.point(root.margins.left, Metrics.barBottom ? root.forScreen.height - root.margins.bottom - root.height : root.margins.top)
            anim: Companion.base === "" && Companion.music ? "dance" : Companion.base

            MouseArea {
                x: parent.width * 0.2
                y: parent.height * 0.12
                width: parent.width * 0.6
                height: parent.height * 0.86
                cursorShape: Qt.PointingHandCursor
                onClicked: Companion.talkNow()
            }
        }

        Bubble {
            width: implicitWidth
            maxWidth: stage.width - Metrics.spacing * 2
            x: Math.max(Metrics.spacing, Math.min(stage.width - width - Metrics.spacing, her.x + her.width / 2 - width / 2))
            y: Metrics.spacing
            tailX: her.x + her.width / 2 - x
        }

        // the pomodoro's clock, in the corner
        Label {
            visible: Companion.pomoPhase !== ""
            x: 6
            y: parent.height - height - 6
            text: Companion.pomoPhase === "break" ? Strings.t("herBreak").arg(Companion.pomoLeft) : Strings.t("herMinutes").arg(Companion.pomoLeft)
            color: Companion.pomoPhase === "break" ? Colors.accent : Colors.fg
        }

        // do not disturb: she won't peek out
        Label {
            visible: Settings.dnd
            x: parent.width - width - 6
            y: parent.height - height - 6
            text: Strings.t("herShh")
            color: Colors.dim
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 0
        elide: Text.ElideRight
        text: `${Strings.t(Companion.sleeping ? "herAsleep" : Companion.night ? "herLate" : Companion.busy ? "herBusy" : "herCalm")} · ${root.together()}`
        color: Colors.dim
    }

    Group {
        visible: root.tab === 0
        title: Strings.t("herLook")

        Repeater {
            model: ["mood", "red", "ink", "stripes"]

            Check {
                required property string modelData

                Layout.fillWidth: true
                radio: true
                text: Strings.t(`herLook_${modelData}`)
                note: modelData === "mood" ? Strings.t("herMoodNote") : ""
                checked: (["red", "ink", "stripes"].includes(Settings.companionLook) ? Settings.companionLook : "mood") === modelData
                onToggled: Settings.companionLook = modelData
            }
        }
    }

    Group {
        visible: root.tab === 0
        title: Strings.t("herDesktop")

        Repeater {
            model: ["walk", "home"]

            Check {
                required property string modelData

                Layout.fillWidth: true
                radio: true
                text: Strings.t(modelData === "walk" ? "herDesktopHers" : "herDesktopNot")
                note: modelData === "walk" ? Strings.t("herWalkNote") : ""
                checked: (Companion.walks ? "walk" : "home") === modelData
                onToggled: Settings.companionMode = modelData
            }
        }
    }

    RowLayout {
        visible: root.tab === 0
        spacing: 6

        // 25 minutes of work, 5 of rest: she tells you when
        PushButton {
            text: Companion.pomoPhase ? Strings.t("herStopFocus").arg(Companion.pomoLeft) : Strings.t("herFocus")
            active: Companion.pomoPhase !== ""
            onClicked: Companion.focus()
        }

        PushButton {
            text: Strings.t(Companion.napping ? "herWake" : "herSleep")
            onClicked: Companion.napping ? Companion.wake() : Companion.sleep()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.tab === 0
        spacing: 6

        Label {
            text: Strings.t("herName")
        }

        TermInput {
            Layout.fillWidth: true
            prompt: ""
            placeholder: Strings.t("herNameHint")
            Component.onCompleted: text = Settings.companionName
            onAccepted: t => Settings.companionName = t.trim().slice(0, 24)
        }
    }

    // ------------------------------------------------------------ talk
    Group {
        Layout.topMargin: Metrics.spacing
        visible: root.tab === 1
        title: Strings.t("herSpeaks")

        Repeater {
            model: [["en", "English"], ["ru", "Русский"]]

            Check {
                required property var modelData

                radio: true
                text: modelData[1]
                checked: Companion.lang === modelData[0]
                onToggled: {
                    Settings.companionLang = modelData[0];
                    Companion.say(Companion.line("hello", ""), 0);
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 1
        wrapMode: Text.Wrap
        text: Strings.t("herPhrases").arg(Companion.lang)
    }

    // your phrases, sunk; × removes one
    Rectangle {
        Layout.fillWidth: true
        visible: root.tab === 1
        implicitHeight: Math.max(3, phrases.count) * (Metrics.fontSize + 9) + 6
        color: Colors.well

        Bevel {
            style: "sunk"
        }

        Label {
            visible: phrases.count === 0
            anchors.centerIn: parent
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Companion.lang === "ru" ? "пока пусто: «как дела?», «я скучала»…" : "none yet: “how's it going?”, “I missed you”…"
            color: Colors.dim
        }

        Column {
            x: 3
            y: 3
            width: parent.width - 6

            Repeater {
                id: phrases

                model: root.tab === 1 ? Companion.own[Companion.lang] ?? [] : []

                Rectangle {
                    id: phrase_

                    required property string modelData
                    required property int index

                    width: parent.width
                    height: Metrics.fontSize + 9
                    color: area.containsMouse ? Colors.accent : "transparent"

                    Label {
                        x: 5
                        width: parent.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: `“${phrase_.modelData}”`
                        color: area.containsMouse ? Colors.onAccent : Colors.fg
                    }

                    Label {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: area.containsMouse
                        text: "×"
                        color: Colors.onAccent
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Companion.removePhrase(phrase_.index)
                    }
                }
            }
        }
    }

    TermInput {
        id: phrase

        Layout.fillWidth: true
        visible: root.tab === 1
        prompt: "+"
        placeholder: Strings.t("herPhraseHint")
        onAccepted: t => {
            Companion.addPhrase(t);
            phrase.text = "";
        }
    }

    Check {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: root.tab === 1
        text: Strings.t("herQuotes")
        note: Companion.lang === "ru" ? Strings.t("herQuotesRu") : Companion.hasFortune ? Strings.t("herQuotesFortune") : Strings.t("herQuotesOwn")
        checked: Settings.companionQuotes
        onToggled: Settings.companionQuotes = !Settings.companionQuotes
    }
}
