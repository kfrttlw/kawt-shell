import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// super + /: every kawt bind, read straight from hypr/kawt.lua (each hl.bind line ends with a
// "-- what it does" comment), so the list can't drift away from the real binds. Then the binds
// of your Hyprland config that carry such a comment: ~/.config/hypr/hyprland.lua, and with
// kawt's standard config hypr/preset.lua (less what user.lua frees with preset.unbind) and
// user.lua. "-- keys: super+1..0 | what" lines stand for binds made in a loop or a group.
// The first one of a key counts: kawt's, then yours, then the standard config's.
// Plus the keys that work inside kawt's own windows.
//
//   ┌ ? Help and keys ─────────────────────────────────── × ┐
//   │ Find: [shot                                        ]  │
//   │ [kawt] [Hyprland] [Inside kawt]                        │
//   │ ┌────────────────────────────────────────────────────┐ │
//   │ │ super+shift+s   screenshot of an area              │ │
//   │ └────────────────────────────────────────────────────┘ │
//   │ 35 keys                │ from hypr/kawt.lua            │
//   └────────────────────────────────────────────────────────┘
// Typing finds in all three (typed in the wrong layout too); tab goes to the next tab.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("keys", forScreen)
    readonly property bool standard: hyprText.includes("hypr/preset.lua") // hyprland.lua loads kawt's standard config
    readonly property var kawtBinds: parse(kawtText) // [{ keys, what }]
    readonly property var hyprBinds: {
        const freed = standard ? unbinds(userText) : [];
        const all = (standard ? parse(userText) : []).concat(parse(hyprText), standard ? parse(presetText).filter(b => !freed.includes(b.keys)) : []);
        return all.filter((b, i) => all.findIndex(o => o.keys === b.keys) === i && !kawtBinds.some(k => k.keys === b.keys));
    }
    property string kawtText: ""
    property string hyprText: ""
    property string presetText: ""
    property string userText: ""

    readonly property var inside: [
        { keys: Strings.t("keysRunBox"), what: Strings.t("keysRunBoxWhat") },
        { keys: Strings.t("keysMenu"), what: Strings.t("keysMenuWhat") },
        { keys: Strings.t("keysToday"), what: Strings.t("keysTodayWhat") },
        { keys: Strings.t("keysTasks"), what: Strings.t("keysTasksWhat") },
        { keys: Strings.t("keysStyle"), what: Strings.t("keysStyleWhat") },
        { keys: Strings.t("keysPower"), what: Strings.t("keysPowerWhat") },
        { keys: Strings.t("keysWindows"), what: Strings.t("keysWindowsWhat") },
        { keys: Strings.t("keysDesk"), what: Strings.t("keysDeskWhat") },
        { keys: Strings.t("keysEverywhere"), what: Strings.t("keysEverywhereWhat") }
    ]
    readonly property var lists: [kawtBinds, hyprBinds, inside]
    readonly property string query: find.text.trim().toLowerCase()
    readonly property string queryAlt: Apps.otherLayout(query)
    readonly property var found: lists.map(l => query ? l.filter(b => {
            const t = `${b.keys} ${b.what}`.toLowerCase();
            return t.includes(query) || (queryAlt !== "" && t.includes(queryAlt));
        }) : l)
    readonly property var shown: found[tabs.current] ?? []

    // found nothing here, something in another tab: that one
    onFoundChanged: if (query && shown.length === 0 && found.some(l => l.length))
        tabs.current = found.findIndex(l => l.length)

    readonly property int rowHeight: Metrics.fontSize + 9
    readonly property int keysWidth: Math.round(Metrics.fontSize * 0.6 * (tabs.current === 2 ? 26 : 22))

    screen: forScreen
    visible: open
    color: "transparent"

    WlrLayershell.namespace: "kawt-keys"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    OpenWatch {
        open: root.open
        onOpened: {
            file.reload();
            hyprFile.reload();
            presetFile.reload();
            userFile.reload();
            find.text = "";
            find.input.forceActiveFocus();
        }
    }

    // "SUPER + SHIFT + S" -> "super+shift+s"
    function pretty(keys: string): string {
        return keys.toLowerCase().replace(/\s*\+\s*/g, "+").replace("slash", "/").replace("escape", "esc");
    }

    // the binds in a lua config, as [{ keys, what }]
    function parse(text: string): var {
        const out = [];
        for (const line of text.split("\n")) {
            // hl.bind(mod .. " + R", ...) -- what   /   bind(mainMod .. ...) (preset.lua)   /   hl.bind("Print", ...) -- what
            const m = line.match(/^\s*(?:hl\.)?bind\((\w*[Mm]od\s*\.\.\s*)?"([^"]+)".*?--\s*(.+)$/);
            if (m) {
                out.push({ keys: root.pretty((m[1] ? "SUPER" : "") + m[2]), what: m[3].trim() });
                continue;
            }
            // -- keys: super+arrows | focus
            const k = line.match(/^\s*--\s*keys:\s*(.+?)\s*\|\s*(.+)$/);
            if (k)
                out.push({ keys: k[1], what: k[2].trim() });
        }
        return out;
    }

    // the keys a user.lua frees: preset.unbind("SUPER + V") -> "super+v"
    function unbinds(text: string): var {
        const out = [];
        for (const line of text.split("\n")) {
            const m = line.match(/^\s*preset\.unbind\(\s*"([^"]+)"\s*\)/);
            if (m)
                out.push(root.pretty(m[1]));
        }
        return out;
    }

    FileView {
        id: file

        path: `${Quickshell.shellDir}/hypr/kawt.lua`
        onLoaded: root.kawtText = text()
    }

    // your own config: missing or the classic hyprland.conf, and the list is kawt's alone
    FileView {
        id: hyprFile

        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr/hyprland.lua`
        printErrors: false
        onLoaded: root.hyprText = text()
        onLoadFailed: root.hyprText = ""
    }

    FileView {
        id: presetFile

        path: `${Quickshell.shellDir}/hypr/preset.lua`
        onLoaded: root.presetText = text()
    }

    FileView {
        id: userFile

        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr/user.lua`
        printErrors: false
        onLoaded: root.userText = text()
        onLoadFailed: root.userText = ""
    }

    // the screen behind, dark in dots; a click there closes it
    Dots {
        anchors.fill: parent
        base: "transparent"
        dots: Qt.rgba(0, 0, 0, 0.7)

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.close()
        }
    }

    KWindow {
        id: box

        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(Math.round(800 * Metrics.scale), root.width - Metrics.padding * 4)
        height: Math.min(Math.round(560 * Metrics.scale), root.height - Metrics.barHeight - 80)
        title: Strings.t("keysTitle")
        icon: "help"
        status: [
            root.query ? Strings.t("keysFound").arg(root.shown.length) : Strings.count(root.shown.length, "key"),
            tabs.current === 0 ? Strings.t("keysFrom").arg("hypr/kawt.lua") : tabs.current === 1 ? Strings.t("keysFrom").arg(root.standard ? "hyprland.lua · user.lua · preset.lua" : "~/.config/hypr/hyprland.lua") : Strings.t("keysInsideNote")
        ]
        onCloseClicked: Panels.close()

        MouseArea {
            anchors.fill: parent
            onClicked: find.input.forceActiveFocus()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Label {
                    text: Strings.t("findWord")
                }

                TermInput {
                    id: find

                    Layout.fillWidth: true
                    prompt: ""
                    placeholder: Strings.t("keysFindHint")

                    Keys.onEscapePressed: {
                        if (find.text !== "")
                            find.text = "";
                        else
                            Panels.close();
                    }
                    Keys.onUpPressed: flick.contentY = Math.max(0, flick.contentY - root.rowHeight * 3)
                    Keys.onDownPressed: flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + root.rowHeight * 3))
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab)
                            tabs.current = (tabs.current + 1) % 3;
                        else if (event.key === Qt.Key_Backtab)
                            tabs.current = (tabs.current + 2) % 3;
                        else
                            return;
                        event.accepted = true;
                    }
                }
            }

            // searching: how many each tab has
            Tabs {
                id: tabs

                Layout.topMargin: 2
                tabs: ["kawt", "Hyprland", Strings.t("keysInside")].map((n, i) => root.query ? `${n} (${root.found[i].length})` : n)
                onCurrentChanged: flick.contentY = 0
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: -6
                color: Colors.well

                Bevel {
                    style: "sunk"
                }

                Label {
                    visible: root.shown.length === 0
                    anchors.centerIn: parent
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: tabs.current === 0 && root.kawtText === "" ? Colors.warn : Colors.dim
                    text: root.query ? `— ${Strings.t("noResults").toLowerCase()} —` : tabs.current === 0 ? Strings.t("keysNoKawt") : Strings.t("keysNoHypr")
                }

                Flickable {
                    id: flick

                    x: 3
                    y: 3
                    width: parent.width - 6
                    height: parent.height - 6
                    clip: true
                    contentHeight: rows.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: rows

                        width: flick.width

                        Repeater {
                            model: root.shown

                            Item {
                                id: row

                                required property var modelData

                                width: rows.width
                                height: Math.max(root.rowHeight, what.implicitHeight + 6)

                                Label {
                                    x: 6
                                    y: 3
                                    width: root.keysWidth - 12
                                    elide: Text.ElideRight
                                    text: row.modelData.keys
                                    color: Colors.accent
                                }

                                Label {
                                    id: what

                                    x: root.keysWidth
                                    y: 3
                                    width: parent.width - x - 6
                                    wrapMode: Text.Wrap
                                    text: row.modelData.what
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
