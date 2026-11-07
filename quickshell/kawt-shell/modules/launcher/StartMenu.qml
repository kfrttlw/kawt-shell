import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The start menu, under the bar's kawt button: one way into everything, each thing in one place.
// A band with kawt's name on the left; on the right the search (type at once: it searches), the
// pinned apps, "All programs ►" (a real cascade, by the apps' categories), the homes (Today,
// System, Settings, Help, the AI, stripes) and "Shut down…".
// Typed: the list becomes results, the programs, then "more" (run it, ask the AI). The launcher's
// prefixes (! > = ? $ : ; .) go on in the launcher in the middle (Launcher.qml), all of them.
// Keys: ↑ ↓ pick, → opens the cascade, ← closes it, enter starts, esc closes.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("menu", forScreen)
    readonly property int rowHeight: Metrics.fontSize + 11
    readonly property int menuWidth: Math.round(280 * Metrics.scale)
    readonly property string query: input.text
    readonly property bool prefixed: /^[!>=?$:;.]/.test(query)

    // what the menu lists: apps, the homes, lines, labels
    readonly property var pinnedApps: (Apps.pinned.length ? Apps.pinned : Apps.search("")).slice(0, 6)
    readonly property var homes: [
        { kind: "all", icon: "apps", text: Strings.t("allApps"), sub: true },
        { kind: "window", icon: "check", text: Strings.t("today"), key: "super+i", window: "today", tab: "today" },
        { kind: "window", icon: "chart", text: Strings.t("system"), window: "system", tab: "sys" },
        { kind: "window", icon: "gear", text: Strings.t("settings"), key: "super+,", window: "settings", tab: "" },
        { kind: "panel", icon: "help", text: Strings.t("help"), key: "super+/", panel: "keys" },
        { kind: "ai", icon: "ai", text: Strings.t("ai"), key: "super+a" },
        { kind: "panel", icon: "stripes", text: "stripes", key: "super+h", panel: "home" }
    ]
    readonly property var found: query.trim() && !prefixed ? Apps.search(query).slice(0, 8) : []
    readonly property var lines: {
        if (query.trim() === "")
            return [...pinnedApps.map(a => ({ kind: "app", app: a })), "-", ...homes, "-", { kind: "panel", icon: "power", text: Strings.t("shutdownDots"), key: "super+esc", panel: "power" }];
        const out = [];
        if (found.length) {
            out.push({ kind: "label", text: Strings.t("programs") });
            out.push(...found.map(a => ({ kind: "app", app: a, note: a.comment || a.genericName || "" })));
            out.push("-");
        }
        out.push({ kind: "label", text: Strings.t("more") });
        out.push({ kind: "run", icon: "run", text: Strings.t("run").arg(query.trim()), key: "!" });
        out.push({ kind: "ask", icon: "ai", text: Strings.t("askAi"), key: "?" });
        return out;
    }
    readonly property var picks: lines.map((l, i) => i).filter(i => lines[i] !== "-" && lines[i].kind !== "label")
    property int current: 0
    readonly property var line: lines[picks[current]] ?? null

    // the cascade: "All programs" -> categories -> their apps
    property bool allOpen: false
    property string category: ""
    readonly property var catNames: ["Network", "Game", "Graphics", "AudioVideo", "Office", "Development", "System", "Utility", "Other"]
    readonly property var byCategory: {
        const out = {};
        for (const a of Apps.search("")) {
            const c = categoryOf(a);
            (out[c] = out[c] ?? []).push(a);
        }
        for (const k in out)
            out[k].sort((x, y) => x.name.localeCompare(y.name));
        return out;
    }

    function categoryOf(app: var): string {
        const cats = app.categories ?? [];
        if (cats.includes("Audio") || cats.includes("Video"))
            return "AudioVideo";
        if (cats.includes("Settings"))
            return "System";
        return catNames.find(c => cats.includes(c)) ?? "Other";
    }

    function activate(l: var): void {
        if (!l)
            return;
        switch (l.kind) {
        case "app":
            Apps.launch(l.app);
            Panels.close();
            break;
        case "all":
            allOpen = true;
            break;
        case "panel":
            Panels.current = l.panel;
            break;
        case "window":
            Panels.openWindow(l.window, l.tab ?? "");
            break;
        case "ai":
            Panels.close();
            Panels.toggleSidebar(forScreen);
            break;
        case "run":
            Apps.run(query.trim());
            Panels.close();
            break;
        case "ask":
            Panels.launcherPrefix = "?" + query.trim();
            Panels.current = "launcher";
            break;
        }
    }

    function move(d: int): void {
        if (picks.length)
            current = (current + d + picks.length) % picks.length;
        allOpen = line?.kind === "all" && allOpen;
    }

    screen: forScreen
    visible: open
    color: "transparent"

    WlrLayershell.namespace: "kawt-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    onQueryChanged: {
        current = 0;
        allOpen = false;
        // a launcher prefix: on in the launcher, with what's typed
        if (prefixed) {
            Panels.launcherPrefix = query;
            Panels.current = "launcher";
        }
    }

    OpenWatch {
        open: root.open
        onOpened: {
            input.text = "";
            root.current = 0;
            root.allOpen = false;
            input.forceActiveFocus();
        }
    }

    // a click outside closes it
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.close()
    }

    // the menu, the band on its left, a hard shadow
    Item {
        id: menu

        x: 2
        y: Metrics.barBottom ? parent.height - Metrics.barHeight - height + 2 : Metrics.barHeight - 2
        width: band.width + root.menuWidth + 8
        height: column.implicitHeight + 8

        Rectangle {
            x: 4
            y: 4
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.face

            Bevel {
                style: "raised"
            }

            MouseArea {
                anchors.fill: parent
            }
        }

        // kawt 1.0, bottom to top, on black; the red block at the foot
        Rectangle {
            id: band

            x: 3
            y: 3
            width: 26
            height: parent.height - 6
            color: Colors.title

            PixIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                name: "logo"
            }

            Row {
                x: 2
                y: parent.height - 28
                rotation: -90
                transformOrigin: Item.TopLeft
                spacing: 6

                Label {
                    text: "kawt"
                    color: Colors.titleInk
                    font.pixelSize: Metrics.times(2)
                    anchors.baseline: ver.baseline
                }

                Label {
                    id: ver

                    text: Kawt.version
                    color: Colors.mix(Colors.titleInk, Colors.title, 0.4)
                }
            }
        }

        ColumnLayout {
            id: column

            x: band.width + 6
            y: 4
            width: root.menuWidth
            spacing: 0

            // the search
            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 3
                implicitHeight: root.rowHeight + 2
                color: Colors.well

                Bevel {
                    style: "sunk"
                }

                PixIcon {
                    x: 5
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                }

                TextInput {
                    id: input

                    x: 26
                    width: parent.width - 32
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.fg
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.onAccent
                    font.family: Metrics.fontFamily
                    font.pixelSize: Metrics.fontSize
                    renderType: Metrics.pixel ? Text.NativeRendering : Text.QtRendering
                    clip: true
                    focus: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (root.allOpen)
                                root.allOpen = false;
                            else
                                Panels.close();
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            root.move(1);
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                            root.move(-1);
                        } else if (event.key === Qt.Key_Right && root.line?.kind === "all") {
                            root.allOpen = true;
                        } else if (event.key === Qt.Key_Left && root.allOpen) {
                            root.allOpen = false;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate(root.line);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }

                    Label {
                        visible: input.text === ""
                        text: Strings.t("search")
                        color: Colors.dim
                    }
                }
            }

            Repeater {
                model: root.lines

                Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool rule: modelData === "-"
                    readonly property bool label: !rule && modelData.kind === "label"
                    readonly property bool picked: root.picks[root.current] === index
                    readonly property bool app: !rule && modelData.kind === "app"

                    Layout.fillWidth: true
                    implicitHeight: rule ? 6 : label ? root.rowHeight - 4 : root.rowHeight

                    // a groove between the groups
                    Rectangle {
                        visible: row.rule
                        y: 2
                        width: parent.width
                        height: 1
                        color: Colors.lo

                        Rectangle {
                            y: 1
                            width: parent.width
                            height: 1
                            color: Colors.hi
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: row.picked
                        color: Colors.accent
                    }

                    AppIcon {
                        visible: row.app
                        x: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        icon: row.app ? (row.modelData.app.icon ?? "") : ""
                        name: row.app ? row.modelData.app.name : ""
                        colored: true
                    }

                    PixIcon {
                        visible: !row.rule && !row.label && !row.app
                        x: 5
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.rule || row.label || row.app ? "" : row.modelData.icon
                    }

                    Label {
                        visible: !row.rule
                        x: row.label ? 5 : 28
                        width: parent.width - x - hint.width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.rule ? "" : row.app ? row.modelData.app.name : row.modelData.text
                        color: row.picked ? Colors.onAccent : row.label ? Colors.dim : Colors.fg
                    }

                    // the key, the app's note, or ► for the cascade
                    Label {
                        id: hint

                        visible: !row.rule && text !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, root.menuWidth * 0.4)
                        elide: Text.ElideRight
                        text: row.rule || row.label ? "" : row.modelData.sub ? "►" : row.modelData.key ?? row.modelData.note ?? ""
                        color: row.picked ? Colors.onAccent : Colors.dim
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.rule && !row.label
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.current = root.picks.indexOf(row.index);
                            if (row.modelData.kind === "all")
                                cascadeTimer.restart();
                            else
                                root.allOpen = false;
                        }
                        onClicked: root.activate(row.modelData)
                    }

                    // where the cascade opens: by this line
                    Component.onCompleted: if (!row.rule && modelData.kind === "all")
                        cascade.anchorRow = row
                }
            }
        }
    }

    Timer {
        id: cascadeTimer

        interval: 300
        onTriggered: root.allOpen = root.line?.kind === "all"
    }

    // All programs: the categories, then a category's apps beside them
    Row {
        id: cascade

        property Item anchorRow: null

        visible: root.allOpen
        x: menu.x + menu.width - 3
        y: menu.y + column.y + (anchorRow?.y ?? 0) - 3
        spacing: -3

        MenuBox {
            rowHeight: root.rowHeight
            items: root.catNames.filter(c => root.byCategory[c]?.length).map(c => ({ icon: "folder", text: Strings.t("cat" + c), sub: true, picked: root.category === c, enter: () => root.category = c }))
        }

        MenuBox {
            rowHeight: root.rowHeight
            visible: root.category !== "" && (root.byCategory[root.category]?.length ?? 0) > 0
            items: (root.byCategory[root.category] ?? []).map(a => ({ app: a, text: a.name, enter: () => {}, click: () => {
                        Apps.launch(a);
                        Panels.close();
                    } }))
        }
    }

    // one box of the cascade: raised, a shadow, a line each
    component MenuBox: Item {
        id: box

        property var items: []
        property int rowHeight: 22 // the start menu's (inline components don't see its ids)

        width: Math.round(220 * Metrics.scale)
        height: Math.min(lines.implicitHeight, 22 * box.rowHeight) + 8

        Rectangle {
            x: 4
            y: 4
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.face

            Bevel {
                style: "raised"
            }
        }

        Flickable {
            x: 3
            y: 4
            width: parent.width - 6
            height: parent.height - 8
            contentHeight: lines.implicitHeight
            clip: true

            Column {
                id: lines

                width: parent.width

                Repeater {
                    model: box.items

                    Item {
                        id: it

                        required property var modelData

                        width: lines.width
                        height: box.rowHeight

                        Rectangle {
                            anchors.fill: parent
                            visible: area.containsMouse || (it.modelData.picked ?? false)
                            color: Colors.accent
                        }

                        AppIcon {
                            visible: !!it.modelData.app
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            icon: it.modelData.app?.icon ?? ""
                            name: it.modelData.text
                            colored: true
                        }

                        PixIcon {
                            visible: !it.modelData.app
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            name: it.modelData.icon ?? ""
                        }

                        Label {
                            x: 26
                            width: parent.width - 44
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: it.modelData.text
                            color: area.containsMouse || (it.modelData.picked ?? false) ? Colors.onAccent : Colors.fg
                        }

                        Label {
                            visible: it.modelData.sub ?? false
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            text: "►"
                            color: area.containsMouse || (it.modelData.picked ?? false) ? Colors.onAccent : Colors.dim
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: it.modelData.enter?.()
                            onClicked: (it.modelData.click ?? it.modelData.enter)?.()
                        }
                    }
                }
            }
        }
    }
}
