import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// The companion's house ([home] in the bar). Tabs:
//   room   him in his room; food, fun and sleep; feed, play, sleep, a pomodoro;
//          whether he stays home, walks the empty desktop, or decides himself
//   look   which one he is (and his name)
//   talk   the language he speaks, your own phrases for him, whether he asks for things
Popover {
    id: root

    name: "home"
    title: `home: ${Companion.name}`
    cardWidth: 320

    readonly property int tab: tabs.current

    // [##########----] for a need, 0..1
    function meter(v: real): string {
        const n = 14, k = Math.round(v * n);
        return `[${"#".repeat(k)}${"-".repeat(n - k)}]`;
    }

    // "3 days together"
    function together(): string {
        const d = Math.floor((Companion.now - (Companion.born || Companion.now)) / 86400000);
        return d < 1 ? "met today" : d === 1 ? "1 day together" : `${d} days together`;
    }

    onCardKey: event => {
        if (event.key === Qt.Key_Tab) {
            tabs.current = (tabs.current + 1) % 3;
            event.accepted = true;
        }
    }

    Tabs {
        id: tabs

        tabs: ["room", "look", "talk"]
    }

    // ------------------------------------------------------------ room
    Room {
        Layout.fillWidth: true
        visible: root.tab === 0
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 0
        elide: Text.ElideRight
        text: `${Companion.name} is ${Companion.mood === "asleep" ? "asleep" : Companion.mood}${Companion.outside && !Companion.sleeping ? " · likes it out" : ""} · ${root.together()}`
        color: Companion.sulking || Companion.wants ? Colors.warn : Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    //  food   [##########----] 70%
    Repeater {
        model: root.tab === 0 ? [["food", Companion.food], ["fun", Companion.fun], ["sleep", Companion.energy]] : []

        Row {
            required property var modelData

            spacing: Metrics.spacing

            Label {
                width: Math.round(42 * Metrics.scale)
                text: modelData[0]
                color: Colors.dim
            }

            Label {
                text: root.meter(modelData[1])
                color: modelData[1] < 0.3 ? Colors.warn : Colors.accent
            }

            Label {
                text: `${Math.round(modelData[1] * 100)}%`
                color: Colors.dim
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        visible: root.tab === 0
        spacing: Metrics.spacing

        BracketButton {
            label: "feed"
            textColor: Companion.wants === "food" ? Colors.accent : Colors.fg
            onClicked: Companion.feed()
        }

        BracketButton {
            label: "play"
            textColor: Companion.wants === "play" ? Colors.accent : Colors.fg
            onClicked: Companion.play()
        }

        BracketButton {
            label: Companion.sleeping ? "wake" : "sleep"
            textColor: Companion.wants === "sleep" ? Colors.accent : Colors.fg
            onClicked: Companion.sleeping ? Companion.wake() : Companion.sleep(false)
        }

        // 25 minutes of work, 5 of rest: he tells you when
        BracketButton {
            label: Companion.pomoPhase ? `stop ${Companion.pomoLeft}m` : "focus 25"
            textColor: Companion.pomoPhase ? Colors.accent : Colors.fg
            onClicked: Companion.focus()
        }
    }

    //  out: [home] [walks] [decides]
    RowLayout {
        visible: root.tab === 0
        spacing: 0

        Label {
            text: "he "
            color: Colors.dim
        }

        Repeater {
            model: [["home", "stays home"], ["walk", "walks"], ["auto", "decides"]]

            BracketButton {
                required property var modelData

                label: modelData[1]
                active: Settings.companionMode === modelData[0]
                textColor: Settings.companionMode === modelData[0] ? Colors.accent : Colors.dim
                bordered: false
                onClicked: Settings.companionMode = modelData[0]
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 0
        wrapMode: Text.Wrap
        text: "out: on an empty desktop. a window opens and he goes home. click him to talk, drag him along the edge, double click: home for an hour"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    // ------------------------------------------------------------ look
    Flow {
        Layout.fillWidth: true
        visible: root.tab === 1
        spacing: Metrics.spacing

        Repeater {
            model: Companion.order

            Item {
                id: pick

                required property string modelData
                readonly property bool chosen: Companion.skinName === modelData

                implicitWidth: Math.max(preview.width, caption.implicitWidth) + Metrics.spacing * 2
                implicitHeight: preview.height + caption.implicitHeight + Metrics.spacing * 2

                Rectangle {
                    anchors.fill: parent
                    color: pick.chosen || pickArea.containsMouse ? Colors.hoverFill : "transparent"
                    border.color: pick.chosen ? Colors.accent : Colors.border
                    border.width: Metrics.borderWidth
                }

                // the chosen one moves, the rest stand still
                Pet {
                    id: preview

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Metrics.spacing
                    cell: Math.max(2, Math.round(2 * Metrics.scale))
                    skin: Companion.skins[pick.modelData]
                    live: pick.chosen
                    anim: "idle"
                }

                Label {
                    id: caption

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: preview.bottom
                    text: Companion.title(pick.modelData)
                    color: pick.chosen ? Colors.accent : Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }

                MouseArea {
                    id: pickArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.companionSkin = pick.modelData
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 1
        wrapMode: Text.Wrap
        text: {
            const a = Companion.skin?.about;
            return typeof a === "string" ? a : (a && (a[Companion.lang] || a.en)) || "one of yours";
        }
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    TermInput {
        Layout.fillWidth: true
        visible: root.tab === 1
        prompt: "name>"
        placeholder: `${Companion.title(Companion.skinName)} (enter keeps it)`
        Component.onCompleted: text = Settings.companionName
        onAccepted: t => Settings.companionName = t.trim().slice(0, 24)
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 1
        wrapMode: Text.Wrap
        text: "your own looks: ~/.config/kawt/companions.json (how: utils/companions.js)"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    // ------------------------------------------------------------ talk
    RowLayout {
        visible: root.tab === 2
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
        visible: root.tab === 2
        text: `your phrases (${Companion.lang}), said when you click him:`
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 2 && (Companion.own[Companion.lang] ?? []).length === 0
        wrapMode: Text.Wrap
        text: Companion.lang === "ru" ? "  пока пусто: «как дела?», «я скучал»..." : "  none yet: \"how's it going?\", \"I missed you\"..."
        color: Colors.dim
    }

    Repeater {
        model: root.tab === 2 ? Companion.own[Companion.lang] ?? [] : []

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
        visible: root.tab === 2
        prompt: "say>"
        placeholder: "a phrase of his, enter adds it"
        onAccepted: t => {
            Companion.addPhrase(t);
            phrase.text = "";
        }
    }

    BracketButton {
        visible: root.tab === 2
        tag: Settings.companionQuotes ? "x" : " "
        label: "wise words now and then"
        bordered: false
        onClicked: Settings.companionQuotes = !Settings.companionQuotes
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 2 && Settings.companionQuotes
        wrapMode: Text.Wrap
        text: Companion.lang === "ru" ? "his own (fortune speaks english only)" : Companion.hasFortune ? "his own and fortune's sayings" : "his own; with fortune-mod (sudo pacman -S fortune-mod) many more"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    BracketButton {
        visible: root.tab === 2
        tag: Settings.companionAsks ? "x" : " "
        label: "he asks for food and play"
        bordered: false
        onClicked: Settings.companionAsks = !Settings.companionAsks
    }

    Label {
        Layout.fillWidth: true
        visible: root.tab === 2
        wrapMode: Text.Wrap
        text: Settings.companionAsks ? "a notification with [feed] / [play] on it, 3 a day at most, never at night or in dnd" : "he never asks: everything is here in the house"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    // off: the house goes from the bar, he stops walking and peeking (back in profile -> cfg)
    BracketButton {
        visible: root.tab === 2
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
        visible: root.tab === 2
        wrapMode: Text.Wrap
        text: "off: no house, no walks, nothing runs for him. on again in profile -> cfg"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }
}
