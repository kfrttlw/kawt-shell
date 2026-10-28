import QtQuick
import qs.config

// One [ or ] of components/Brackets.qml, for a button with more inside than a word (the net
// graph, the player): the same colors, gone with Settings.brackets off.
Label {
    property bool closing: false // ] instead of [ (not `right`: every item has that, an anchor line)
    property string look: "" // "" | "on" | "off" | "warn", as in Brackets
    property bool shown: true // false: the room stays, the glyph doesn't

    visible: Settings.brackets
    text: !shown ? " " : closing ? "]" : "["
    color: look === "on" ? Colors.accent : look === "warn" ? Colors.warn : look === "off" ? Colors.bracketOff : Colors.bracket
}
