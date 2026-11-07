import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// stripes' window ([≡] in the bar). Tabs:
//   her    she herself; her look, whether an empty desktop is hers, a pomodoro, sleep, her name
//   talk   the language she speaks, your own phrases for her, wise words, off
Popover {
    id: root

    name: "home"
    title: Companion.name
    cardWidth: 320

    readonly property int tab: tabs.current

    // "3 days together"
    function together(): string {
        const d = Math.floor((Companion.now - (Companion.born || Companion.now)) / 86400000);
        return d < 1 ? "met today" : d === 1 ? "1 day together" : `${d} days together`;
    }

    onCardKey: event => {
        if (event.key === Qt.Key_Tab) {
            tabs.current = (tabs.current + 1) % 2;
            event.accepted = true;
        }
    }

    Tabs {
        id: tabs

        tabs: ["her", "talk"]
    }

    // ------------------------------------------------------------ her
    // her place: she stands at the bottom, what she says over her
    Well {
        id: stage

        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(210 * Metrics.scale)
        visible: root.tab === 0
        clip: true

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
            x: Metrics.spacing
            y: parent.height - height - Metrics.spacing
            text: Companion.pomoPhase === "break" ? `[break ${Companion.pomoLeft}m]` : `[${Companion.pomoLeft}m]`
            color: Companion.pomoPhase === "break" ? Colors.accent : Colors.fg
            font.pixelSize: Metrics.size(-2)
        }

        // do not disturb: she won't peek out
        Label {
            visible: Settings.dnd
            x: parent.width - width - Metrics.spacing
            y: parent.height - height - Metrics.spacing
            text: "[shh]"
            color: Colors.dim
            font.pixelSize: Metrics.size(-2)
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 0
        elide: Text.ElideRight
        text: `${Companion.sleeping ? "asleep" : Companion.night ? "up late" : Companion.busy ? "busy" : "calm"} · ${root.together()}`
        color: Colors.dim
        font.pixelSize: Metrics.size(-2)
    }

    //  look: [mood] [red] [ink] [stripes]
    RowLayout {
        visible: root.tab === 0
        spacing: 0

        Label {
            text: "look "
            color: Colors.dim
        }

        Repeater {
            model: ["mood", "red", "ink", "stripes"]

            BracketButton {
                required property string modelData
                readonly property bool picked: (["red", "ink", "stripes"].includes(Settings.companionLook) ? Settings.companionLook : "mood") === modelData

                label: modelData
                active: picked
                textColor: picked ? Colors.accent : Colors.dim
                bordered: false
                onClicked: Settings.companionLook = modelData
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 0 && !["red", "ink", "stripes"].includes(Settings.companionLook)
        wrapMode: Text.Wrap
        text: "by her mood: stripes when calm, red when busy (music, the coder, a recording), ink at night and asleep"
        color: Colors.dim
        font.pixelSize: Metrics.size(-2)
    }

    //  an empty desktop: [hers] [not hers]
    RowLayout {
        visible: root.tab === 0
        spacing: 0

        Label {
            text: "an empty desktop "
            color: Colors.dim
        }

        Repeater {
            model: [["walk", "is hers"], ["home", "isn't"]]

            BracketButton {
                required property var modelData
                readonly property bool picked: (Companion.walks ? "walk" : "home") === modelData[0]

                label: modelData[1]
                active: picked
                textColor: picked ? Colors.accent : Colors.dim
                bordered: false
                onClicked: Settings.companionMode = modelData[0]
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        visible: root.tab === 0
        spacing: Metrics.spacing

        // 25 minutes of work, 5 of rest: she tells you when
        BracketButton {
            label: Companion.pomoPhase ? `stop ${Companion.pomoLeft}m` : "focus 25"
            textColor: Companion.pomoPhase ? Colors.accent : Colors.fg
            onClicked: Companion.focus()
        }

        BracketButton {
            label: Companion.napping ? "wake her" : "sleep"
            onClicked: Companion.napping ? Companion.wake() : Companion.sleep()
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 0
        wrapMode: Text.Wrap
        text: "on an empty desktop she walks about and falls asleep when nothing happens; a window opens and she goes. click her to talk, drag her along the edge, double click: away for an hour. super + h calls her, again: lets her go"
        color: Colors.dim
        font.pixelSize: Metrics.size(-2)
    }

    TermInput {
        Layout.fillWidth: true
        visible: root.tab === 0
        prompt: "name>"
        placeholder: "stripes (enter keeps it)"
        Component.onCompleted: text = Settings.companionName
        onAccepted: t => Settings.companionName = t.trim().slice(0, 24)
    }

    // ------------------------------------------------------------ talk
    RowLayout {
        visible: root.tab === 1
        spacing: 0

        Label {
            text: "speaks "
            color: Colors.dim
        }

        Repeater {
            model: [["en", "english"], ["ru", "русский"]]

            BracketButton {
                required property var modelData

                label: modelData[1]
                active: Companion.lang === modelData[0]
                textColor: Companion.lang === modelData[0] ? Colors.accent : Colors.dim
                bordered: false
                onClicked: {
                    Settings.companionLang = modelData[0];
                    Companion.say(Companion.line("hello", ""), 0);
                }
            }
        }
    }

    Label {
        visible: root.tab === 1
        text: `your phrases (${Companion.lang}), said when you click her:`
        color: Colors.dim
        font.pixelSize: Metrics.size(-2)
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 1 && (Companion.own[Companion.lang] ?? []).length === 0
        wrapMode: Text.Wrap
        text: Companion.lang === "ru" ? "  пока пусто: «как дела?», «я скучала»..." : "  none yet: \"how's it going?\", \"I missed you\"..."
        color: Colors.dim
    }

    Repeater {
        model: root.tab === 1 ? Companion.own[Companion.lang] ?? [] : []

        RowLayout {
            required property string modelData
            required property int index

            Layout.fillWidth: true
            spacing: Metrics.spacing

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: `  "${modelData}"`
            }

            BracketButton {
                label: "x"
                bordered: false
                textColor: Colors.dim
                onClicked: Companion.removePhrase(index)
            }
        }
    }

    TermInput {
        id: phrase

        Layout.fillWidth: true
        visible: root.tab === 1
        prompt: "say>"
        placeholder: "a phrase of hers, enter adds it"
        onAccepted: t => {
            Companion.addPhrase(t);
            phrase.text = "";
        }
    }

    BracketButton {
        visible: root.tab === 1
        tag: Settings.companionQuotes ? "x" : " "
        label: "wise words now and then"
        bordered: false
        onClicked: Settings.companionQuotes = !Settings.companionQuotes
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 1 && Settings.companionQuotes
        wrapMode: Text.Wrap
        text: Companion.lang === "ru" ? "her own (fortune speaks english only)" : Companion.hasFortune ? "her own and fortune's sayings" : "her own; with fortune-mod (sudo pacman -S fortune-mod) many more"
        color: Colors.dim
        font.pixelSize: Metrics.size(-2)
    }

    // off: [≡] goes from the bar, she stops walking and peeking (back in profile -> cfg)
    BracketButton {
        visible: root.tab === 1
        tag: "x"
        label: "the companion"
        bordered: false
        onClicked: {
            Panels.close();
            Settings.companion = false;
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 1
        wrapMode: Text.Wrap
        text: "off: no [≡], no walks, nothing runs for her. on again in profile -> cfg -> kawt"
        color: Colors.dim
        font.pixelSize: Metrics.size(-2)
    }
}
