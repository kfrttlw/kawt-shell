import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// super + space: the run box, the old way, in the middle of the screen.
//
//   ┌ 🔍 kawt — run ─────────────────────────────── × ┐
//   │ Open: [fire█                    ] [Programs  ▼] │
//   │ ┌─────────────────────────────────────────────┐ │
//   │ │ ◯ Firefox                       web browser │ │  the picked one red
//   │ │ ▭ Files                              thunar │ │
//   │ └─────────────────────────────────────────────┘ │
//   │ ↑↓ pick · enter open    │ ctrl+s pin · tab mode │
//   └─────────────────────────────────────────────────┘
//
// The modes are a list on the right of the field (a click on it or alt + ↓; tab: the next one), and
// still prefixes, typed straight in: ! a command (shift + enter: in a terminal; > on its own
// still starts it in one), = the calculator, ? a short answer from the ai (enter again: the whole
// talk in the ai panel), $ a command from the ai (enter: it's written; enter again: into the
// command line, to look at and run; tab: copy; it never runs by itself), : the clipboard, ; open
// windows, . emoji. → on an app with actions of its own (firefox: a private window) lists them.
// The calculator's and the ai's answers come big in the field instead of a list.
// The list is a ScriptModel with reused rows: typing a letter re-sorts the rows that are already
// there instead of making all of them (and their icons) again.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("launcher", forScreen)
    readonly property int maxRows: 8
    readonly property int rowHeight: Metrics.fontSize + 11

    readonly property var modes: [
        { prefix: "", name: "modeApps", icon: "apps" },
        { prefix: "!", name: "modeCmd", icon: "run" },
        { prefix: "=", name: "modeCalc", icon: "calc" },
        { prefix: "?", name: "modeAi", icon: "ai" },
        { prefix: "$", name: "modeAiCmd", icon: "terminal" },
        { prefix: ":", name: "modeClip", icon: "clip" },
        { prefix: ";", name: "modeWin", icon: "win" },
        { prefix: ".", name: "modeEmoji", icon: "emoji" }
    ]
    readonly property string query: input.text
    // > (in a terminal) is the command mode, its first line the terminal's
    readonly property string typed: /^[!>=?$:;.]/.test(query) ? query[0] : ""
    readonly property string mode: typed === ">" ? "!" : typed
    readonly property int modeIndex: modes.findIndex(m => m.prefix === mode)
    readonly property string arg: typed ? query.slice(1).trim() : query
    // the plain calculator at once; with qalc, what it can't do a moment later (services/Apps.qml)
    readonly property string calcPlain: mode === "=" ? Apps.calc(arg) : ""
    readonly property string calcResult: mode !== "=" ? "" : calcPlain || (Apps.qalcFor === arg ? Apps.qalcOut : "")
    // the app whose own actions are listed (→ on it); typing goes back to the search
    property var expanded: null
    // $ and ?: the ai's answer is there, for what's typed now (Ai is only named in these modes:
    // naming it at all loads the whole ai service, and all saved chats)
    readonly property bool cmdReady: mode === "$" && Ai.cmdFor === arg && Ai.cmdText !== "" && !Ai.cmdBusy
    readonly property bool shortReady: mode === "?" && Ai.shortFor === arg && !Ai.shortBusy && (Ai.shortText !== "" || Ai.shortError !== "")
    readonly property bool answers: mode === "=" || mode === "?" || mode === "$"
    property bool modesOpen: false

    // what the list shows, one line each: { kind, text, note, icon | app | glyph, ... }
    readonly property var lines: {
        if (!open || answers)
            return [];
        if (mode === "!") {
            const hist = Apps.runs.filter(c => c !== arg && c.toLowerCase().includes(arg.toLowerCase()));
            return [
                ...(arg ? [
                    { kind: "run", icon: "run", text: Strings.t("runLine").arg(arg), cmd: arg, note: "enter" },
                    { kind: "term", icon: "terminal", text: Strings.t("termLine").arg(arg), cmd: arg, note: "shift+enter" }
                ] : []),
                ...hist.slice(0, 20).map(c => ({ kind: "run", icon: "run", text: c, cmd: c, note: Strings.t("historyWord"), old: true }))
            ];
        }
        if (mode === ":")
            return Clipboard.search(arg).map(e => {
                const img = Clipboard.isImage(e);
                // "[[ binary data 23 KiB png 1920x1080 ]]"
                const m = img ? /binary data (.+?) (\w+) (\d+)x(\d+)/.exec(e.text) : null;
                return { kind: "clip", icon: img ? "picture" : "clip", entry: e, image: img, text: img ? Strings.t("clipPicture").arg(m ? `${m[3]}×${m[4]}` : "") : e.text.replace(/\s+/g, " "), note: m ? `${m[2]} · ${m[1]}` : "" };
            });
        if (mode === ";") {
            const alt = Apps.otherLayout(arg.toLowerCase());
            return Hypr.windows.filter(w => {
                const t = `${w.title} ${w.lastIpcObject?.class ?? ""}`.toLowerCase();
                return t.includes(arg.toLowerCase()) || (alt !== "" && t.includes(alt));
            }).map(w => {
                const cls = w.lastIpcObject?.class ?? "";
                return { kind: "win", win: w, appIcon: DesktopEntries.heuristicLookup(cls)?.icon ?? "", appName: cls || w.title || "?", text: w.title || cls, note: [w.workspace ? `${Strings.t("desk").toLowerCase()} ${w.workspace.id}` : "", cls.toLowerCase()].filter(s => s).join(" · ") };
            });
        }
        if (mode === ".") {
            // the russian names next to the english ones on a russian (ukrainian...) system, or
            // when that's what's typed; the other english names otherwise
            const cyr = Strings.ru || /^(ru|uk|be)/.test(Qt.locale().name) || /[а-яёіїєґ]/i.test(arg);
            return Emoji.search(arg).map(e => ({ kind: "emoji", item: e, glyph: e.e, text: e.en, note: cyr ? e.ru : e.other }));
        }
        const apps = expanded ? [expanded, ...Apps.actionsOf(expanded)] : Apps.search(query).slice(0, 60);
        return apps.map(a => ({ kind: "app", app: a, appIcon: a.icon, appName: a.name, text: a.name, note: a.isAction ? Strings.t("actionWord") : (a.genericName || a.comment || "").toLowerCase() }));
    }
    property int current: 0
    readonly property var line: lines[current] ?? null

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

    OpenWatch {
        open: root.open
        onOpened: {
            input.text = Panels.launcherPrefix;
            Panels.launcherPrefix = "";
            root.current = root.typed === ">" ? 1 : 0;
            root.modesOpen = false;
            input.input.forceActiveFocus();
        }
    }
    onQueryChanged: {
        current = typed === ">" && arg ? 1 : 0;
        expanded = null;
    }
    onCurrentChanged: {
        list.positionViewAtIndex(current, ListView.Contain);
        if (line?.image)
            Clipboard.show(line.entry);
    }
    onLinesChanged: if (line?.image)
        Clipboard.show(line.entry)
    onModeChanged: {
        if (mode === ":")
            Clipboard.refresh();
        else if (mode === ";")
            Hypr.refreshWindows();
        else if (mode === ".")
            Emoji.wanted = true; // the list is read the first time
    }
    onArgChanged: if (mode === "=" && arg && !Apps.calc(arg))
        Apps.qalc(arg)

    function move(delta: int): void {
        if (modesOpen) {
            setMode(modeIndex + delta);
            return;
        }
        if (lines.length > 0)
            current = (current + delta + lines.length) % lines.length;
    }

    function setMode(i: int): void {
        const m = modes[(i + modes.length) % modes.length];
        input.text = m.prefix + arg;
        input.input.cursorPosition = input.text.length;
        input.input.forceActiveFocus();
    }

    function copy(text: string): void {
        try {
            Quickshell.clipboardText = text;
        } catch (e) {
            Quickshell.execDetached(["wl-copy", "--", text]); // older quickshell
        }
    }

    // enter (shift + enter: `inTerminal`)
    function accept(inTerminal: bool): void {
        const l = line;
        if (modesOpen) {
            modesOpen = false;
            return;
        }
        if (mode === "!" && l) {
            Apps.remember(l.cmd);
            if (inTerminal || l.kind === "term")
                Apps.runInTerminal(l.cmd);
            else
                Apps.run(l.cmd);
        } else if (mode === "=" && calcResult) {
            copy(calcResult.replace(/^[≈=]\s*/, "")); // qalc's "≈ 0.33": the number
        } else if (mode === "?" && arg) {
            // the short answer first; enter again (or shift + enter at once): the ai panel
            if (!inTerminal && !shortReady) {
                Ai.shortAnswer(arg);
                return;
            }
            Panels.sidebarScreen = forScreen.name;
            Panels.sidebarOpen = true;
            Ai.send(arg);
        } else if (mode === "$" && arg) {
            // the command written: into the command line, to read (and change) before it runs
            if (cmdReady) {
                input.text = `>${Ai.cmdText}`;
                input.input.cursorPosition = input.text.length;
            } else {
                Ai.suggestCommand(arg);
            }
            return;
        } else if (mode === ":" && l) {
            Clipboard.copy(l.entry);
        } else if (mode === ";" && l) {
            Hypr.focusWindow(l.win);
        } else if (mode === "." && l) {
            Emoji.pick(l.item);
        } else if (!mode && l) {
            Apps.launch(l.app);
        } else {
            return;
        }
        Panels.close();
    }

    // the two cells of the status bar: what the keys do here
    readonly property var hints: {
        const k = s => Strings.t(s);
        if (modesOpen)
            return [k("hintPickTake"), k("hintNextMode")];
        if (mode === "!")
            return [k("hintRun"), Apps.runs.length ? k("hintForget") : k("hintMode")];
        if (mode === "=")
            return [k("hintCopy"), k("hintMode")];
        if (mode === "?")
            return [shortReady ? k("hintAiPanel") : k("hintAsk"), k("hintMode")];
        if (mode === "$")
            return [cmdReady ? k("hintIntoCmd") : k("hintWrite"), cmdReady ? k("hintCopyCmd") : k("hintMode")];
        if (mode === ":")
            return [k("hintPickCopy"), k("hintForget")];
        if (mode === ";")
            return [k("hintPickGo"), k("hintMode")];
        if (mode === ".")
            return [Emoji.canType ? k("hintPickType") : k("hintPickCopy"), k("hintMode")];
        if (expanded)
            return [k("hintPickRun"), k("hintBack")];
        const actions = (line?.app?.actions?.length ?? 0) > 0 && !line?.app?.isAction;
        return [(actions ? k("hintActions") + " · " : "") + k("hintPickOpen"), k("hintPin")];
    }

    // a click outside closes it
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.close()
    }

    KWindow {
        id: box

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height * 0.18)
        width: Math.min(Math.round(600 * Metrics.scale), root.width - Metrics.padding * 2)
        height: chrome + body.implicitHeight
        title: Strings.t("runTitle")
        icon: "search"
        pad: 6
        status: root.hints
        onCloseClicked: Panels.close()

        MouseArea {
            anchors.fill: parent // swallow clicks so they don't close it
            onClicked: root.modesOpen = false
        }

        ColumnLayout {
            id: body

            width: parent.width
            spacing: 6

            // Open: [what's typed] [mode ▼]
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Label {
                    text: Strings.t("runOpen")
                }

                TermInput {
                    id: input

                    Layout.fillWidth: true
                    prompt: ""
                    placeholder: Strings.t("runPlaceholder")
                    shiftEnter: true
                    onAccepted: root.accept(false)
                    onShiftAccepted: root.accept(true)

                    // TextInput doesn't use these keys, so they bubble up to here
                    Keys.onEscapePressed: {
                        if (root.modesOpen)
                            root.modesOpen = false;
                        else if (root.expanded)
                            root.expanded = null;
                        else
                            Panels.close();
                    }
                    Keys.onUpPressed: root.move(-1)
                    // alt + ↓: the modes' list, as old drop-down lists opened
                    Keys.onDownPressed: event => {
                        if (event.modifiers & Qt.AltModifier)
                            root.modesOpen = !root.modesOpen;
                        else
                            root.move(1);
                    }
                    // at the end of the line: the picked app's own actions
                    Keys.onRightPressed: event => {
                        const app = root.line?.app;
                        if (!root.mode && !root.expanded && app && !app.isAction && (app.actions?.length ?? 0) > 0) {
                            root.expanded = app;
                            root.current = 0;
                        } else {
                            event.accepted = false;
                        }
                    }
                    Keys.onLeftPressed: event => {
                        if (root.expanded)
                            root.expanded = null;
                        else
                            event.accepted = false;
                    }
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        const l = root.line;
                        if (event.key === Qt.Key_Tab && !ctrl && root.cmdReady) {
                            root.copy(Ai.cmdText);
                            Panels.close();
                        } else if (event.key === Qt.Key_Tab)
                            root.setMode(root.modeIndex + 1);
                        else if (event.key === Qt.Key_Backtab)
                            root.setMode(root.modeIndex - 1);
                        else if (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))
                            root.move(1);
                        else if (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))
                            root.move(-1);
                        else if (ctrl && event.key === Qt.Key_D && l?.kind === "clip")
                            Clipboard.remove(l.entry);
                        else if (ctrl && event.key === Qt.Key_D && l?.old)
                            Apps.forget(l.cmd);
                        else if (ctrl && event.key === Qt.Key_S && l?.kind === "app")
                            Apps.togglePin(l.app);
                        else if (ctrl && event.key === Qt.Key_O && l?.kind === "app")
                            Apps.setOffline(l.app.isAction ? l.app.app.id : l.app.id, !Apps.isOffline(l.app));
                        else
                            return;
                        event.accepted = true;
                    }
                }

                // the mode: a box with ▼, the list opens under it
                Rectangle {
                    id: modeBox

                    Layout.preferredWidth: Math.round(Metrics.fontSize * 0.6 * 17) + 22
                    Layout.fillHeight: true
                    color: Colors.well

                    Bevel {
                        style: "sunk"
                    }

                    Label {
                        x: 5
                        width: drop.x - x - 4
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: Strings.t(root.modes[Math.max(0, root.modeIndex)].name)
                    }

                    ArrowButton {
                        id: drop

                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.top: parent.top
                        anchors.topMargin: 2
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: 16
                        dir: "down"
                        down: root.modesOpen
                        onClicked: root.modesOpen = !root.modesOpen
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: drop.width + 2
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.modesOpen = !root.modesOpen
                    }
                }
            }

            // the list, or the answer, sunk
            Rectangle {
                id: well

                Layout.fillWidth: true
                implicitHeight: root.maxRows * root.rowHeight + 6
                color: Colors.well

                Bevel {
                    style: "sunk"
                }

                ListView {
                    id: list

                    x: 3
                    y: 3
                    width: (preview.visible ? preview.x - 3 : parent.width - 3) - x
                    height: parent.height - 6
                    visible: !root.answers
                    clip: true
                    reuseItems: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: ScriptModel {
                        values: root.lines
                    }

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool picked: index === root.current
                        readonly property color ink: picked ? Colors.onAccent : Colors.fg

                        width: list.width
                        height: root.rowHeight
                        color: picked ? Colors.accent : "transparent"

                        AppIcon {
                            id: appIcon

                            visible: row.modelData.appName !== undefined
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            icon: row.modelData.appIcon ?? ""
                            name: row.modelData.appName ?? ""
                            colored: true
                        }

                        PixIcon {
                            visible: row.modelData.icon !== undefined
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.icon ?? ""
                        }

                        Label {
                            visible: row.modelData.glyph !== undefined
                            x: 2
                            width: 20
                            horizontalAlignment: Text.AlignHCenter
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.glyph ?? ""
                        }

                        // the typed letters stand out
                        Label {
                            id: words

                            x: 28
                            width: Math.min(implicitWidth, parent.width - x - (note.text ? note.implicitWidth + 16 : 6) - (marks.visible ? marks.implicitWidth + 6 : 0))
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            textFormat: row.modelData.kind === "app" ? Text.StyledText : Text.PlainText
                            text: row.modelData.kind === "app" ? Apps.highlight(row.modelData.text, root.query, row.picked ? Colors.onAccent : Colors.accent) : row.modelData.text
                            color: row.ink
                        }

                        // pinned (★), started without internet
                        Label {
                            id: marks

                            readonly property bool pin: row.modelData.kind === "app" && Apps.isPinned(row.modelData.app)
                            readonly property bool off: row.modelData.kind === "app" && Apps.isOffline(row.modelData.app)

                            visible: pin || off
                            x: words.x + words.width + 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: [pin ? "★" : "", off ? Strings.t("noNetWord") : ""].filter(s => s).join(" ")
                            color: row.picked ? Colors.onAccent : Colors.accent
                        }

                        Label {
                            id: note

                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, row.width * 0.4)
                            elide: Text.ElideRight
                            text: row.modelData.note ?? ""
                            color: row.picked ? Colors.onAccent : Colors.dim
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            // not onEntered: that also fires when the list scrolls under a resting mouse
                            onPositionChanged: root.current = row.index
                            onClicked: mouse => {
                                root.current = row.index;
                                if (mouse.button !== Qt.RightButton)
                                    root.accept(false);
                                else if (row.modelData.kind === "app")
                                    Apps.togglePin(row.modelData.app);
                                else if (row.modelData.kind === "clip")
                                    Clipboard.remove(row.modelData.entry);
                                else if (row.modelData.old)
                                    Apps.forget(row.modelData.cmd);
                            }
                        }
                    }
                }

                // a copied picture: how it looks, on the right
                Rectangle {
                    id: preview

                    visible: root.mode === ":" && (root.line?.image ?? false) && Clipboard.shownPath !== ""
                    x: Math.round(parent.width * 0.6)
                    y: 6
                    width: parent.width - x - 6
                    height: parent.height - 12
                    color: Colors.face

                    Bevel {
                        style: "well"
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        source: preview.visible ? `file://${Clipboard.shownPath}` : ""
                    }
                }

                // nothing in the list: why
                Label {
                    visible: !root.answers && root.lines.length === 0
                    anchors.centerIn: parent
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Colors.dim
                    text: {
                        if (root.mode === ":" && !Clipboard.available)
                            return Strings.t("clipNeeds");
                        if (root.mode === "." && Emoji.all.length === 0)
                            return Strings.t("emojiReading");
                        if (root.mode === "!")
                            return Strings.t("cmdEmpty");
                        if (root.arg)
                            return `— ${Strings.t("noResults").toLowerCase()} —`;
                        return root.mode === ":" ? `— ${Strings.t("clipEmpty")} —` : root.mode === ";" ? `— ${Strings.t("winEmpty")} —` : `— ${Strings.t("noResults").toLowerCase()} —`;
                    }
                }

                // = ? $: the answer, big
                ColumnLayout {
                    visible: root.answers
                    x: 10
                    y: 8
                    width: parent.width - 20
                    spacing: 6

                    Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        maximumLineCount: root.mode === "?" ? 5 : 3
                        elide: Text.ElideRight
                        font.pixelSize: root.mode === "?" && Ai.shortText.length > 60 ? Metrics.fontSize : Metrics.times(2)
                                                text: {
                            if (root.mode === "=")
                                return root.calcResult ? `${/^[≈=]/.test(root.calcResult) ? "" : "= "}${root.calcResult}` : "";
                            if (root.mode === "?")
                                return root.shortReady ? Ai.shortText : "";
                            if (root.mode === "$")
                                return root.cmdReady ? Ai.cmdText : "";
                            return "";
                        }
                    }

                    // what the command does, what to look out for
                    Label {
                        Layout.fillWidth: true
                        visible: root.cmdReady && text !== ""
                        wrapMode: Text.Wrap
                        text: root.cmdReady ? Ai.cmdAbout : ""
                    }

                    Label {
                        readonly property var risks: root.cmdReady ? Ai.risks(Ai.cmdText) : []

                        Layout.fillWidth: true
                        visible: risks.length > 0
                        wrapMode: Text.Wrap
                        text: Strings.t("cmdCareful").arg(risks.join(", "))
                        color: Colors.warn
                    }

                    // what happens on enter, or what to type
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: (root.mode === "?" && root.shortReady && Ai.shortError) || (root.mode === "$" && Ai.cmdFor === root.arg && Ai.cmdError) ? Colors.warn : Colors.dim
                        text: {
                            const model = root.mode === "?" || root.mode === "$" ? Ai.modelName : "";
                            if (root.mode === "=")
                                return root.calcResult ? Strings.t("calcCopy").arg(Apps.hasQalc ? "qalc" : Strings.t("calcPlainWord")) : root.arg ? "—" : Apps.hasQalc ? Strings.t("calcHelpQalc") : Strings.t("calcHelp");
                            if (root.mode === "?") {
                                if (!root.arg)
                                    return Strings.t("aiShortHelp");
                                if (Ai.shortBusy && Ai.shortFor === root.arg)
                                    return Strings.t("aiThinking").arg(model);
                                if (root.shortReady)
                                    return Ai.shortError ? `!! ${Ai.shortError}` : Strings.t("aiShortDone").arg(model);
                                return Strings.t("aiShortAsk").arg(model);
                            }
                            if (!root.arg)
                                return Strings.t("aiCmdHelp");
                            if (Ai.cmdBusy)
                                return Strings.t("aiWriting").arg(model);
                            if (Ai.cmdFor === root.arg && Ai.cmdError)
                                return `!! ${Ai.cmdError}`;
                            return root.cmdReady ? Strings.t("aiCmdDone") : Strings.t("aiCmdAsk").arg(model);
                        }
                    }
                }
            }

            // the clipboard: clear it all (a second click: sure?)
            RowLayout {
                Layout.fillWidth: true
                visible: root.mode === ":" && Clipboard.entries.length > 0

                Label {
                    Layout.fillWidth: true
                    text: Strings.count(root.lines.length, "copied")
                    color: Colors.dim
                }

                PushButton {
                    id: wipe

                    property bool armed: false

                    text: armed ? Strings.t("sureAgain") : Strings.t("clipWipe")
                    onClicked: {
                        if (armed) {
                            armed = false;
                            Clipboard.wipe();
                        } else {
                            armed = true;
                            disarm.restart();
                        }
                    }

                    Timer {
                        id: disarm

                        interval: 3000
                        onTriggered: wipe.armed = false
                    }
                }
            }
        }
    }

    // the modes, under their box: an icon, the name, the prefix grey on the right
    Item {
        id: modeList

        visible: root.modesOpen
        readonly property point at: root.modesOpen ? modeBox.mapToItem(null, 0, modeBox.height) : Qt.point(0, 0)

        x: at.x + modeBox.width - width
        y: at.y + 1
        width: Math.round(Metrics.fontSize * 0.6 * 22) + 40
        height: modeColumn.implicitHeight + 6

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

        Column {
            id: modeColumn

            x: 3
            y: 3
            width: parent.width - 6

            Repeater {
                model: root.modes

                Rectangle {
                    id: modeRow

                    required property var modelData
                    required property int index
                    readonly property bool picked: index === Math.max(0, root.modeIndex)

                    width: modeColumn.width
                    height: root.rowHeight
                    color: picked || modeArea.containsMouse ? Colors.accent : "transparent"

                    PixIcon {
                        x: 4
                        anchors.verticalCenter: parent.verticalCenter
                        name: modeRow.modelData.icon
                    }

                    Label {
                        x: 26
                        anchors.verticalCenter: parent.verticalCenter
                        text: Strings.t(modeRow.modelData.name)
                        color: modeRow.color === Colors.accent ? Colors.onAccent : Colors.fg
                    }

                    Label {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: modeRow.modelData.prefix || "–"
                        color: modeRow.color === Colors.accent ? Colors.onAccent : Colors.dim
                    }

                    MouseArea {
                        id: modeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.setMode(modeRow.index);
                            root.modesOpen = false;
                        }
                    }
                }
            }
        }
    }
}
