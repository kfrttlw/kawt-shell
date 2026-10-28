import QtQuick
import qs.config
import qs.components
import qs.services

// [⌂] the companion's house in the bar, a button like the others: the house bright while he's
// home and awake, dim while he's out on the desktop or asleep. After it: s asleep, ! when he
// wants something (food, a game, sleep), the minutes of a running pomodoro.
BarBox {
    id: root

    readonly property bool out: Companion.deskViews > 0
    readonly property bool lit: !out && !Companion.sleeping
    readonly property string tag: Companion.pomoPhase ? `${Companion.pomoLeft}m` : Companion.wants || Companion.sulking ? "!" : Companion.sleeping ? "s" : ""

    visible: Companion.enabled && Settings.barShows("home")

    Bracket {
        look: root.active ? "on" : ""
    }

    Label {
        text: "⌂"
        color: root.lit ? Colors.fg : Colors.dim
    }

    Label {
        visible: root.tag !== ""
        text: ` ${root.tag}`
        color: root.tag === "!" ? Colors.warn : Colors.dim
    }

    Bracket {
        closing: true
        look: root.active ? "on" : ""
    }
}
