import QtQuick
import qs.config
import qs.components
import qs.services

// the bell; a red dot on it while there are new messages. A click: the list of them
BarIcon {
    icon: Notifs.unread > 0 ? "bellDot" : "bell"
    tip: Notifs.unread > 0 ? Strings.t("notifsNew").arg(Notifs.unread) : `${Strings.t("notifs")}: ${Notifs.count}${Settings.dnd ? " · dnd" : ""}`
}
