import QtQuick
import qs.config
import qs.components
import qs.services

// Today (super + i, start -> Today): the day's tasks, the todo list, notes, the focus timer, a
// tab each, in a window of its own. Under it the day in three cells: what's done, the focus
// rounds, the keys
AppWindow {
    id: root

    readonly property int done: Todo.doneToday.length
    readonly property int all: done + Todo.dueToday.length

    name: "today"
    icon: "check"
    title: `${Strings.t("today")} — ${Qt.locale(Strings.ru ? "ru_RU" : "en_US").toString(Time.now, "dddd, d MMMM")}`
    bodyWidth: Math.round(Metrics.fontSize * 56)
    bodyHeight: Math.round(Metrics.fontSize * 25) // one size for every tab: a window doesn't jump when the tab changes
    status: [
        Strings.t("doneOf").arg(done).arg(all),
        Strings.t("focusRounds").arg(Strings.count(Focus.todayRounds, "round")),
        Strings.t("todayKeys")
    ]

    Component.onCompleted: {
        if (Panels.todayTab !== "")
            content.show(Panels.todayTab);
        Panels.todayTab = "";
    }

    Connections {
        target: Panels

        // asked for a tab while it's open
        function onTodayTabChanged(): void {
            if (Panels.todayTab === "")
                return;
            content.show(Panels.todayTab);
            Panels.todayTab = "";
        }
    }

    ProfileContent {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        open: true
        tabNames: ["today", "todo", "notes", "focus"]
    }
}
