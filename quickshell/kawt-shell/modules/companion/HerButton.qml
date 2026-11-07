import QtQuick
import qs.config
import qs.components
import qs.services

// [≡] stripes in the bar (kawt's stripes, her name), a button like the others: her window.
// Bright while she's awake, dim asleep. After it: the minutes of a running pomodoro, or z asleep.
BarBox {
    id: root

    readonly property string tag: Companion.pomoPhase ? `${Companion.pomoLeft}m` : Companion.sleeping ? "z" : ""

    visible: Companion.enabled && Settings.barShows("home")

    Bracket {
        look: root.active ? "on" : ""
    }

    Label {
        text: "≡"
        color: Companion.sleeping ? Colors.dim : Colors.fg
    }

    Label {
        visible: root.tag !== ""
        text: ` ${root.tag}`
        color: Colors.dim
    }

    Bracket {
        closing: true
        look: root.active ? "on" : ""
    }
}
