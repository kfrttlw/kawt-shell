import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// ┌──────────────────────────────────────────────────┐
// │ ≡ Welcome to kawt · 2 / 6                    ☑ On │
// │ ┌──────┐  the keyboard does most things here       │
// │ │ ░▒░  │  super+space   the run box               │
// │ │ ▒█▒  │  super+d       the start menu            │
// │ └──────┘  ...                                     │
// │ ▮▮▯▯▯▯                    [< Back] [Next >] [Skip] │
// └──────────────────────────────────────────────────┘
// The first start: stripes says hello and shows the few things worth knowing, in six short
// steps, like an old system's setup wizard, in her language (english or russian, picked on the
// first one, with her name).
// Once: closed or done, it's not shown again (Settings.welcomed); again from settings -> kawt ->
// Tour, or `qs -c kawt-shell ipc call kawt welcome`.
Popover {
    id: root

    name: "welcome"
    title: `${ru ? "Добро пожаловать в kawt" : "Welcome to kawt"} · ${step + 1} / ${steps.length}`
    icon: "stripes"
    cardWidth: 500

    readonly property bool ru: Companion.lang === "ru"
    property int step: 0

    // per step: what she says, what she does meanwhile, the lines under it ([keys, what])
    readonly property var steps: ru ? [
        { say: `привет! я ${Companion.name}, живу тут, в kawt. давай покажу, что где, это быстро`, anim: "", lines: [] },
        { say: "почти всё здесь делается с клавиатуры", anim: "type", lines: [
            ["super + space", "запуск: программы, команды, примеры"],
            ["super + d", "«Пуск», он же кнопка kawt на панели"],
            ["super + q / e / b", "терминал, файлы, браузер"],
            ["super + /", "все клавиши, в любой момент"]] },
        { say: "сделай его своим", anim: "", lines: [
            ["super + w", "обои и тема"],
            ["super + shift + w", "тёмная <-> светлая"],
            ["super + ,", "настройки: панель, экран, окна, звук"],
            ["", "тема красит всё: терминал, thunar, рамки окон"]] },
        { say: "маленький ии, весь на этом компьютере", anim: "think", lines: [
            ["super + a", "панель ии (ollama)"],
            ["super + alt + a", "про выделенный текст"],
            ["super + alt + v", "сказать голосом"]] },
        { say: "а это я", anim: "", lines: [
            ["«Пуск» -> stripes", "я, мой вид и что я говорю"],
            ["пустой стол", "я там гуляю, а когда ничего не происходит, засыпаю"],
            ["super + h", "позвать меня, ещё раз: отпустить"],
            ["", "не нужна? выключается флажком в моём окне"]] },
        { say: "вот и всё! удачи", anim: "dance", lines: [
            ["super + i", "«Сегодня»: задачи, заметки, фокус"],
            ["мониторы", "~/kawt/install.sh --monitors"],
            ["ещё раз", "настройки -> kawt -> «Знакомство»"]] }
    ] : [
        { say: `hi! I'm ${Companion.name}, I live here in kawt. let me show you around, it's quick`, anim: "", lines: [] },
        { say: "the keyboard does most things here", anim: "type", lines: [
            ["super + space", "the run box: apps, commands, sums"],
            ["super + d", "the start menu, the kawt button in the bar"],
            ["super + q / e / b", "terminal, files, browser"],
            ["super + /", "every key, any time"]] },
        { say: "make it yours", anim: "", lines: [
            ["super + w", "wallpaper and theme"],
            ["super + shift + w", "dark <-> light"],
            ["super + ,", "settings: the bar, the screen, windows, sound"],
            ["", "the theme colors it all: the terminal, thunar, the borders"]] },
        { say: "a little ai, all on this machine", anim: "think", lines: [
            ["super + a", "the ai panel (ollama)"],
            ["super + alt + a", "on the text you marked"],
            ["super + alt + v", "speak to it"]] },
        { say: "and this is me", anim: "", lines: [
            ["start -> stripes", "me, my look and what I say"],
            ["an empty desktop", "I walk about there, and fall asleep when nothing happens"],
            ["super + h", "call me, again: let me go"],
            ["", "don't want me? the switch in my window turns me off"]] },
        { say: "that's all! have fun", anim: "dance", lines: [
            ["super + i", "today: tasks, notes, the focus timer"],
            ["monitors", "~/kawt/install.sh --monitors"],
            ["this again", "settings -> kawt -> Tour"]] }
    ]
    readonly property var now: steps[step]
    readonly property bool last: step === steps.length - 1

    function go(d: int): void {
        step = Math.max(0, Math.min(steps.length - 1, step + d));
    }

    // each step comes with a hop
    onStepChanged: her.hop()

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
        spacing: Metrics.padding

        // her, sunk on the left, as a wizard's picture
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: her.width + 8
            implicitHeight: Math.max(her.height + 8, Math.round(170 * Metrics.scale))
            color: Colors.well
            clip: true

            Bevel {
                style: "sunk"
            }

            Her {
                id: her

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                size: Math.round(120 * Metrics.scale)
                forScreen: root.forScreen
                origin: Qt.point(root.margins.left, Metrics.barBottom ? root.forScreen.height - root.margins.bottom - root.height : root.margins.top)
                anim: root.now.anim

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Companion.talkNow()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 4

            // what she says
            Label {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                wrapMode: Text.Wrap
                text: root.now.say
                font.pixelSize: Metrics.size(2)
            }

            // the first step: her language and her name
            Group {
                visible: root.step === 0
                title: root.ru ? "Говорит" : "She speaks"

                Repeater {
                    model: [["en", "English"], ["ru", "Русский"]]

                    Check {
                        required property var modelData

                        radio: true
                        text: modelData[1]
                        checked: Companion.lang === modelData[0]
                        onToggled: Settings.companionLang = modelData[0]
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.step === 0
                spacing: 6

                Label {
                    text: root.ru ? "Имя:" : "Name:"
                }

                TermInput {
                    Layout.fillWidth: true
                    prompt: ""
                    placeholder: root.ru ? "stripes (или своё, enter)" : "stripes (or one of yours, enter)"
                    Component.onCompleted: text = Settings.companionName
                    onAccepted: t => {
                        Settings.companionName = t.trim().slice(0, 24);
                        root.go(1);
                    }
                }
            }

            //  super + space      the run box
            Repeater {
                model: root.now.lines

                RowLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Metrics.spacing

                    Label {
                        Layout.preferredWidth: Math.round(Metrics.fontSize * 0.6 * 18)
                        Layout.alignment: Qt.AlignTop
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
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        spacing: 6

        // where you are: a block a step, the done ones red; a click goes there
        Row {
            spacing: 2

            Repeater {
                model: root.steps.length

                Rectangle {
                    required property int index

                    width: 8
                    height: 12
                    color: index <= root.step ? Colors.accent : Colors.well

                    Bevel {
                        visible: index > root.step
                        style: "sunk"
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -2
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.step = index
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        PushButton {
            enabled: root.step > 0
            text: root.ru ? "< Назад" : "< Back"
            onClicked: root.go(-1)
        }

        PushButton {
            text: root.last ? (root.ru ? "Готово" : "Finish") : (root.ru ? "Дальше >" : "Next >")
            isDefault: true
            onClicked: root.last ? root.done() : root.go(1)
        }

        PushButton {
            visible: !root.last
            text: root.ru ? "Пропустить" : "Skip"
            onClicked: root.done()
        }
    }
}
