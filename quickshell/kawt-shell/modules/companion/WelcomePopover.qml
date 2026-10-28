import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// ┌─hello: 1 / 6──────────────────────────────────esc┐
// │  ▄█▄   ┌──────────────────────────────────┐        │
// │  ███   │ hi! I'm stripes, I live in kawt   │        │
// │        └──────────────────────────────────┘        │
// │  super + space      apps                          │
// │  ...                                               │
// │  ■ ■ □ □ □ □                 [< back] [enter next] │
// └────────────────────────────────────────────────────┘
// The first start: the companion says hello and shows the few things worth knowing, in six
// short steps, in his language (english or russian, picked on the first one, with his name).
// Once: closed or done, it's not shown again (Settings.welcomed); again from profile -> cfg -> kawt ->
// [tour], or `qs -c kawt-shell ipc call kawt welcome`.
Popover {
    id: root

    name: "welcome"
    title: `${ru ? ["привет", "клавиши", "вид", "ии", "я", "всё"][step] : ["hello", "keys", "look", "ai", "me", "that's all"][step]}: ${step + 1} / ${steps.length}`
    cardWidth: 480

    readonly property bool ru: Companion.lang === "ru"
    property int step: 0

    // per step: what he says, his move, the lines under it ([keys, what])
    readonly property var steps: ru ? [
        { say: `привет! я ${Companion.name}, живу тут, в kawt. давай покажу, что где, это быстро`, anim: "wave", lines: [] },
        { say: "почти всё здесь делается с клавиатуры", anim: "typing", lines: [
            ["super + space", "программы"],
            ["super + q / e / b", "терминал, файлы, браузер"],
            ["super + d", "закреплённые программы"],
            ["super + /", "все клавиши, в любой момент"]] },
        { say: "сделай его своим", anim: "happy", lines: [
            ["super + w", "обои и темы"],
            ["super + shift + w", "тёмная <-> светлая"],
            ["", "тема красит всё: терминал, thunar, рамки окон"]] },
        { say: "маленький ии, весь на этом компьютере", anim: "think", lines: [
            ["super + a", "панель ии (ollama)"],
            ["super + alt + a", "про выделенный текст"],
            ["super + alt + v", "сказать голосом"]] },
        { say: "а это я", anim: "jump", lines: [
            ["[⌂] на панели", "мой дом: покорми, поиграй, уложи спать"],
            ["пустой стол", "я выхожу погулять"],
            ["", "не нужен? выключается в доме -> talk"]] },
        { say: "вот и всё! удачи", anim: "dance", lines: [
            ["профиль", "слева на панели: настройки (cfg), окна в своём размере"],
            ["мониторы", "~/kawt/install.sh --monitors"],
            ["ещё раз", "профиль -> cfg -> kawt -> [tour]"]] }
    ] : [
        { say: `hi! I'm ${Companion.name}, I live here in kawt. let me show you around, it's quick`, anim: "wave", lines: [] },
        { say: "the keyboard does most things here", anim: "typing", lines: [
            ["super + space", "apps"],
            ["super + q / e / b", "terminal, files, browser"],
            ["super + d", "pinned apps"],
            ["super + /", "every key, any time"]] },
        { say: "make it yours", anim: "happy", lines: [
            ["super + w", "wallpapers and themes"],
            ["super + shift + w", "dark <-> light"],
            ["", "the theme colors it all: the terminal, thunar, the borders"]] },
        { say: "a little ai, all on this machine", anim: "think", lines: [
            ["super + a", "the ai panel (ollama)"],
            ["super + alt + a", "on the text you marked"],
            ["super + alt + v", "speak to it"]] },
        { say: "and this is me", anim: "jump", lines: [
            ["[⌂] in the bar", "my house: feed me, play, put me to bed"],
            ["an empty desktop", "I go for a walk"],
            ["", "don't want me? off in my house -> talk"]] },
        { say: "that's all! have fun", anim: "dance", lines: [
            ["the profile", "left in the bar: settings (cfg), windows at their own size"],
            ["monitors", "~/kawt/install.sh --monitors"],
            ["this again", "profile -> cfg -> kawt -> [tour]"]] }
    ]
    readonly property var now: steps[step]
    readonly property bool last: step === steps.length - 1

    function go(d: int): void {
        step = Math.max(0, Math.min(steps.length - 1, step + d));
    }

    function done(): void {
        Panels.close();
    }

    // seen once it's open: closed any way (esc, a click outside), it doesn't come back
    onPanelOpened: {
        step = 0;
        Settings.welcomed = true;
    }

    // enter / → next, ← back
    onCardKey: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) {
            if (last)
                done();
            else
                go(1);
        } else if (event.key === Qt.Key_Left) {
            go(-1);
        } else {
            return;
        }
        event.accepted = true;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing * 2

        Pet {
            Layout.alignment: Qt.AlignTop
            cell: Math.max(2, Math.round(4 * Metrics.scale))
            anim: root.now.anim

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Companion.talkNow()
            }
        }

        // what he says, in a box
        Rectangle {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: said.implicitHeight + Metrics.spacing * 2
            color: Colors.hoverFill
            border.color: Colors.border
            border.width: Metrics.borderWidth

            Label {
                id: said

                anchors.fill: parent
                anchors.margins: Metrics.spacing
                wrapMode: Text.Wrap
                text: root.now.say
            }
        }
    }

    // the first step: his language and his name
    RowLayout {
        visible: root.step === 0
        spacing: 0

        Label {
            text: root.ru ? "говорит " : "speaks "
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
                onClicked: Settings.companionLang = modelData[0]
            }
        }
    }

    TermInput {
        Layout.fillWidth: true
        visible: root.step === 0
        prompt: root.ru ? "имя>" : "name>"
        placeholder: root.ru ? `${Companion.title(Companion.skinName)} (или своё, enter)` : `${Companion.title(Companion.skinName)} (or one of yours, enter)`
        Component.onCompleted: text = Settings.companionName
        onAccepted: t => {
            Settings.companionName = t.trim().slice(0, 24);
            root.go(1);
        }
    }

    //  super + space      apps
    Repeater {
        model: root.now.lines

        RowLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: Metrics.spacing

            Label {
                Layout.preferredWidth: Math.round(150 * Metrics.scale)
                visible: modelData[0] !== ""
                text: modelData[0]
                color: Colors.accent
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: modelData[1]
                color: modelData[0] !== "" ? Colors.fg : Colors.dim
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        spacing: Metrics.spacing

        // ■ ■ □ □ □ □: where you are; a click goes there
        Repeater {
            model: root.steps.length

            Label {
                required property int index

                text: index <= root.step ? "■" : "□"
                color: index === root.step ? Colors.accent : Colors.dim

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.step = index
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        BracketButton {
            visible: root.step > 0
            tag: "<"
            label: root.ru ? "назад" : "back"
            onClicked: root.go(-1)
        }

        BracketButton {
            visible: !root.last
            tag: "esc"
            label: root.ru ? "пропустить" : "skip"
            textColor: Colors.dim
            onClicked: root.done()
        }

        BracketButton {
            tag: "enter"
            label: root.last ? (root.ru ? "готово" : "done") : (root.ru ? "дальше" : "next")
            textColor: Colors.accent
            onClicked: root.last ? root.done() : root.go(1)
        }
    }
}
