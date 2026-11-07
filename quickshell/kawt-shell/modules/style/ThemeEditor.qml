import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// A theme of your own, or other colors for kawt's, without typing json: a name, the colors of
// each variant (dark and light) as #rrggbb, one picked off the screen (hyprpicker), and a little
// bar and panel drawn in them as you type. Saved to ~/.config/kawt/themes.json (config/Colors.qml)
// and chosen at once.
//   New…   starts from the theme you're in (the wallpaper's too: its colors, kept as they are)
//   Edit…  the theme you're in. Black and white keep only what you change: Reset drops it
// The frames' colors (face, edges, fields, the title bar) come from these, as config/Colors.qml
// makes them; the little desktop on top shows them. esc: back, nothing saved. ctrl+s: save.
Item {
    id: root

    property bool shown: false
    property bool isNew: true
    property string name: ""
    property string side: "dark" // the variant being edited
    property var work: ({ dark: ({}), light: ({}) })
    property string sure: "" // "delete" | "reset": asked once more
    property bool picking: false // the style window steps aside meanwhile: hyprpicker sees the screen
    property string pickKey: ""

    readonly property var cur: work[side] ?? ({})
    readonly property bool kawts: !isNew && !!Colors.fixed[name]
    readonly property string nameError: !isNew ? "" : !/^[a-z0-9-]{1,24}$/.test(name) ? Strings.t("teNameChars") : ["thinkpad", "wallpaper", "black", "white"].includes(name) ? Strings.t("teNameKawts") : Colors.themes[name] ? Strings.t("teNameTaken") : ""
    // what each color is for, in the order they're asked
    readonly property var rows: [["bg", "teBg"], ["bar", "teBar"], ["fg", "teFg"], ["dim", "teDim"], ["border", "teBorder"], ["accent", "teAccent"], ["warn", "teWarn"], ["hoverFill", "teHover"]]
    // the frames from these colors, as config/Colors.qml makes them
    readonly property var look: {
        const c = cur, bg = c.bg ?? Colors.bg, fg = c.fg ?? Colors.fg, accent = c.accent ?? Colors.accent;
        const dark = Colors.luminance(bg) < 0.25, mix = Colors.mix;
        const title = c.title ?? (dark ? mix(bg, "black", 0.3) : fg);
        return {
            bg, fg, accent,
            dim: c.dim ?? Colors.dim,
            warn: c.warn ?? Colors.warn,
            bar: c.bar || bg,
            face: c.face ?? (dark ? mix(bg, fg, 0.07) : bg),
            hi: c.hi ?? (dark ? mix(bg, fg, 0.34) : mix(bg, "white", 0.85)),
            hi2: c.hi2 ?? (dark ? mix(bg, fg, 0.16) : mix(bg, "white", 0.4)),
            lo: c.lo ?? (dark ? mix(bg, "black", 0.6) : mix(bg, fg, 0.42)),
            deep: c.deep ?? (dark ? "black" : fg),
            well: c.field ?? (dark ? mix(bg, "black", 0.35) : mix(bg, "white", 0.7)),
            title,
            titleInk: c.titleInk ?? (Colors.luminance(title) < 0.3 ? mix(fg, "white", 0.6) : "#141414"),
            onAccent: Colors.contrast(accent, "white") >= Colors.contrast(accent, "#141414") * 0.8 ? "white" : "#141414"
        };
    }
    // the light in a few colors, a click away
    readonly property var lights: ["#e2231a", "#ff7a1a", "#f2c12e", "#5ec269", "#2ec4b6", "#4c9be8", "#9b6cf0", "#e55aa0", "#d8d6d0"]

    signal closed

    // opened at a variant: its tab
    onSideChanged: sides.current = side === "light" ? 1 : 0

    visible: shown && !picking

    // a new one: the theme you're in, in both variants
    function openNew(): void {
        const t = Colors.themes[Colors.mode];
        work = {
            dark: Object.assign({}, t.dark),
            light: Object.assign({}, t.light)
        };
        let n = "mine", i = 2;
        while (Colors.themes[n])
            n = `mine-${i++}`;
        name = n;
        isNew = true;
        start();
        nameInput.input.forceActiveFocus();
        nameInput.input.selectAll();
    }

    // the theme you're in; the wallpaper's is made again from the picture, so it's copied
    function openEdit(): void {
        if (Colors.mode === "wallpaper") {
            openNew();
            return;
        }
        const t = Colors.themes[Colors.mode];
        work = {
            dark: Object.assign({}, t.dark),
            light: Object.assign({}, t.light)
        };
        name = Colors.mode;
        isNew = false;
        start();
        card.forceActiveFocus();
    }

    function start(): void {
        side = Colors.variant;
        sure = "";
        shown = true;
    }

    function close(): void {
        shown = false;
        closed();
    }

    // #rrggbb (the # may be left out); the bar may be empty: the background's then
    function setColor(key: string, t: string): void {
        t = t.trim().replace(/^#/, "").toLowerCase();
        if (key === "bar" && t === "")
            put(key, "");
        else if (/^[0-9a-f]{6}$/.test(t))
            put(key, "#" + t);
    }

    function put(key: string, v: string): void {
        const w = {
            dark: Object.assign({}, work.dark),
            light: Object.assign({}, work.light)
        };
        if (v)
            w[side][key] = v;
        else
            delete w[side][key];
        work = w;
    }

    function save(): void {
        if (nameError || Colors.userError)
            return;
        Colors.saveTheme(name, work.dark, work.light);
        Settings.theme = name;
        Settings.light = side === "light";
        close();
    }

    // yours: gone; kawt's: its own colors again. Asked once more first
    function drop(): void {
        const what = kawts ? "reset" : "delete";
        if (sure !== what) {
            sure = what;
            return;
        }
        Colors.removeTheme(name);
        close();
    }

    // a color off the screen: kawt steps aside, hyprpicker freezes what's under it
    function pick(key: string): void {
        pickKey = key;
        picking = true;
        pickLater.restart();
    }

    Timer {
        id: pickLater

        interval: 200 // the style window is off the screen by then
        onTriggered: picker.running = true
    }

    Process {
        id: picker

        command: ["hyprpicker", "-n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /#?([0-9a-fA-F]{6})/.exec(text);
                if (m)
                    root.setColor(root.pickKey, m[1]);
            }
        }
        onExited: {
            root.picking = false;
            card.forceActiveFocus();
        }
    }

    // around the card: a click there is a cancel
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    KWindow {
        id: card

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height * 0.08)
        width: Math.min(Math.round(620 * Metrics.scale), root.width - Metrics.padding * 2)
        height: chrome + body.implicitHeight
        title: root.isNew ? Strings.t("teNew") : root.kawts ? Strings.t("teKawts") : Strings.t("teTheme").arg(root.name)
        icon: "edit"
        status: [Strings.t("teKeys"), root.kawts ? Strings.t("teKawtsNote") : "~/.config/kawt/themes.json"]
        onCloseClicked: root.close()

        Keys.onEscapePressed: root.close()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                root.save();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: card.forceActiveFocus()
        }

        ColumnLayout {
            id: body

            width: parent.width
            spacing: Metrics.spacing

            //  Name: [mine          ]
            RowLayout {
                Layout.fillWidth: true
                visible: root.isNew
                spacing: 6

                Label {
                    text: Strings.t("herName")
                }

                TermInput {
                    id: nameInput

                    Layout.fillWidth: true
                    prompt: ""
                    text: root.name
                    placeholder: Strings.t("teNameChars")
                    onTextChanged: if (input.activeFocus)
                        root.name = text.trim().toLowerCase()
                }
            }

            Label {
                visible: root.nameError !== "" || Colors.userError !== ""
                text: Colors.userError ? Strings.t("teFixFile").arg(Colors.userError) : root.nameError
                color: Colors.warn
            }

            // the variant being edited
            Tabs {
                id: sides

                tabs: root.kawts ? [Strings.t("teBlack"), Strings.t("teWhite")] : [Strings.t("teDark"), Strings.t("teLight")]
                current: root.side === "light" ? 1 : 0
                onCurrentChanged: root.side = current === 1 ? "light" : "dark"
            }

            // ---- how it looks: a little desktop in its colors
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: -Metrics.spacing
                implicitHeight: Math.round(150 * Metrics.scale)
                color: root.look.bg
                clip: true

                Bevel {
                    style: "sunk"
                }

                // the bar: the start button, a window button, the clock
                Rectangle {
                    id: miniBar

                    x: 1
                    y: 1
                    width: parent.width - 2
                    height: Metrics.fontSize + 9
                    color: root.look.bar === root.look.bg ? root.look.face : root.look.bar

                    Bevel {
                        style: "raised"
                        colors: root.look
                        }

                    Rectangle {
                        x: 3
                        y: 3
                        width: startWord.implicitWidth + 22
                        height: parent.height - 6
                        color: root.look.face

                        Bevel {
                            style: "raised"
                            colors: root.look
                            }

                        Rectangle {
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 10
                            color: root.look.accent
                        }

                        Label {
                            id: startWord

                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "kawt"
                            color: root.look.fg
                        }
                    }

                    Rectangle {
                        x: 70
                        y: 3
                        width: Math.min(160, parent.width * 0.35)
                        height: parent.height - 6
                        color: root.look.face

                        Bevel {
                            style: "pressed"
                            colors: root.look
                            }

                        Label {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: "kitty — ~/notes"
                            color: root.look.fg
                        }
                    }

                    Label {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "21:04"
                        color: root.look.fg
                    }
                }

                // a window: the title in focus, a list with the picked line, a button
                Rectangle {
                    x: Math.round(parent.width * 0.12)
                    y: miniBar.height + 12
                    width: Math.round(parent.width * 0.62)
                    height: parent.height - y - 10
                    color: root.look.face

                    Rectangle {
                        x: 4
                        y: 4
                        z: -1
                        width: parent.width
                        height: parent.height
                        color: Qt.rgba(0, 0, 0, 0.5)
                    }

                    Bevel {
                        style: "raised"
                        colors: root.look
                        }

                    Rectangle {
                        id: miniTitle

                        x: 3
                        y: 3
                        width: parent.width - 6
                        height: Metrics.fontSize + 7
                        color: root.look.title

                        Label {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: Strings.t("teSample")
                            color: root.look.titleInk
                        }
                    }

                    Rectangle {
                        x: 8
                        y: miniTitle.y + miniTitle.height + 6
                        width: parent.width * 0.62
                        height: parent.height - y - 8
                        color: root.look.well

                        Bevel {
                            style: "sunk"
                            colors: root.look
                            }

                        Column {
                            x: 3
                            y: 3
                            width: parent.width - 6

                            Label {
                                x: 4
                                text: Strings.t("teText")
                                color: root.look.fg
                            }

                            Rectangle {
                                width: parent.width
                                height: Metrics.fontSize + 5
                                color: root.look.accent

                                Label {
                                    x: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Strings.t("tePicked")
                                    color: root.look.onAccent
                                }
                            }

                            Label {
                                x: 4
                                text: Strings.t("teQuiet")
                                color: root.look.dim
                            }

                            Label {
                                x: 4
                                text: Strings.t("teAlert")
                                color: root.look.warn
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        width: okWord.implicitWidth + 24
                        height: Metrics.fontSize + 9
                        color: root.look.face

                        Bevel {
                            style: "raised"
                            colors: root.look
                            }

                        Label {
                            id: okWord

                            anchors.centerIn: parent
                            text: "OK"
                            color: root.look.fg
                        }
                    }
                }
            }

            // ---- the colors:  Background  [##]  # 0c0c0c  [Pick]
            Repeater {
                model: root.rows

                RowLayout {
                    id: row

                    required property var modelData
                    readonly property string key: modelData[0]
                    readonly property string value: root.cur[key] ?? ""
                    readonly property bool ok: /^#?[0-9a-fA-F]{6}$/.test(hex.text.trim()) || (key === "bar" && hex.text.trim() === "")

                    Layout.fillWidth: true
                    spacing: 6

                    Label {
                        Layout.preferredWidth: Math.round(Metrics.fontSize * 0.6 * 20)
                        text: Strings.t(row.modelData[1])
                    }

                    Rectangle {
                        implicitWidth: Math.round(Metrics.fontSize * 2.4)
                        implicitHeight: Metrics.fontSize + 6
                        color: row.value || root.cur.bg || Colors.bg

                        Bevel {
                            style: "sunk"
                        }
                    }

                    TermInput {
                        id: hex

                        Layout.fillWidth: true
                        prompt: "#"
                        promptColor: row.ok ? Colors.dim : Colors.warn
                        text: row.value.replace(/^#/, "")
                        placeholder: row.key === "bar" ? Strings.t("teBarSame") : "rrggbb"
                        onTextChanged: if (input.activeFocus)
                            root.setColor(row.key, text)
                    }

                    PushButton {
                        visible: Screenshot.canFreeze // hyprpicker is there
                        small: true
                        text: Strings.t("tePick")
                        onClicked: root.pick(row.key)
                    }
                }
            }

            //  The light:  ■ ■ ■ ■ ■ ■ ■ ■ ■
            RowLayout {
                spacing: 4

                Label {
                    Layout.preferredWidth: Math.round(Metrics.fontSize * 0.6 * 20) + 2
                    text: Strings.t("teLights")
                }

                Repeater {
                    model: root.lights

                    Rectangle {
                        required property string modelData
                        readonly property bool on: root.cur.accent === modelData

                        implicitWidth: Metrics.fontSize + 6
                        implicitHeight: implicitWidth
                        color: Colors.face

                        Bevel {
                            style: parent.on ? "pressed" : "raised"
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            color: parent.modelData
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.put("accent", parent.modelData)
                        }
                    }
                }
            }

            //  [Delete]                          [Save] [Cancel]
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                spacing: 6

                PushButton {
                    visible: !root.isNew && (!root.kawts || !!Colors.user[root.name])
                    text: root.sure ? Strings.t("sureAgain") : root.kawts ? Strings.t("teReset") : Strings.t("teDelete")
                    onClicked: root.drop()
                }

                Item {
                    Layout.fillWidth: true
                }

                PushButton {
                    isDefault: true
                    enabled: !root.nameError && !Colors.userError
                    text: Strings.t("teSave")
                    onClicked: root.save()
                }

                PushButton {
                    text: Strings.t("cancel")
                    onClicked: root.close()
                }
            }
        }
    }
}
