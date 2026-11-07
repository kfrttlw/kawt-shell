import QtQuick
import qs.config
import qs.components
import qs.services

// the time only (its format: the clock settings); the date in the tip, in kawt's language. A
// click: the calendar with the day's tasks
BarIcon {
    text: Time.barText
    tip: Strings.t("clockTip").arg(Qt.locale(Strings.ru ? "ru_RU" : "en_US").toString(Time.now, "dddd, d MMMM yyyy"))
}
