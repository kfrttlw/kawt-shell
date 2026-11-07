import qs.config
import qs.components
import qs.services

// [log 3] — accent while there are unread messages, [dnd 3] in do-not-disturb mode
BracketButton {
    tag: Settings.dnd ? "dnd" : "log"
    label: String(Notifs.count)
    textColor: Notifs.unread > 0 ? Colors.accent : Notifs.count > 0 ? Colors.fg : Colors.dim
}
