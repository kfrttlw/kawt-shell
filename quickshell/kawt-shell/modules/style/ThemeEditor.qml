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
//   [+ new]  starts from the theme you're in (the wallpaper's too: its colors, kept as they are)
//   [edit]   the theme you're in. Black and white keep only what you change: [reset] drops it
// esc: back to the style window, nothing saved. ctrl+s: save.
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
    readonly property string nameError: !isNew ? "" : !/^[a-z0-9-]{1,24}$/.test(name) ? "a-z, 0-9 and - only" : ["thinkpad", "wallpaper", "black", "white"].includes(name) ? "that one is kawt's" : Colors.themes[name] ? "taken: another name" : ""
    // what each color is for, in the order they're asked
    readonly property var rows: [["bg", "background"], ["bar", "the bar"], ["fg", "text"], ["dim", "quiet text"], ["border", "lines"], ["accent", "the light"], ["warn", "alerts"], ["hoverFill", "under the pointer"]]
    // the light in a few colors, a click away
    readonly property var lights: ["#e2231a", "#ff7a1a", "#f2c12e", "#5ec269", "#2ec4b6", "#4c9be8", "#9b6cf0", "#e55aa0", "#d8d6d0"]

    signal closed

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

    TitledBox {
        id: card

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height * 0.1)
        width: Math.min(Math.round(620 * Metrics.scale), root.width - Metrics.padding * 2)
        height: body.implicitHeight + Metrics.padding * 2 + titleOverhang
        title: root.isNew ? "new theme" : root.kawts ? "kawt's black and white" : `theme: ${root.name}`
        hint: "esc"

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

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + card.titleOverhang
            spacing: Metrics.spacing

            //  name> mine                       [dark] [light]
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                TermInput {
                    id: nameInput

                    Layout.fillWidth: true
                    visible: root.isNew
                    prompt: "name>"
                    text: root.name
                    placeholder: "a-z, 0-9 and -"
                    onTextChanged: if (input.activeFocus)
                        root.name = text.trim().toLowerCase()
                }

                Label {
                    Layout.fillWidth: true
                    visible: !root.isNew
                    text: root.kawts ? "only what you change is kept; [reset] gives kawt's back" : `in ~/.config/kawt/themes.json`
                    color: Colors.dim
                    elide: Text.ElideRight
                }

                Repeater {
                    model: [["dark", root.kawts ? "black" : "dark"], ["light", root.kawts ? "white" : "light"]]

                    BracketButton {
                        required property var modelData

                        label: modelData[1]
                        active: root.side === modelData[0]
                        textColor: root.side === modelData[0] ? Colors.accent : Colors.dim
                        onClicked: root.side = modelData[0]
                    }
                }
            }

            Label {
                visible: root.nameError !== "" || Colors.userError !== ""
                text: Colors.userError ? `${Colors.userError} (fix the file first)` : root.nameError
                color: Colors.warn
                font.pixelSize: Metrics.fontSize - 2
            }

            // ---- how it looks: the bar, and a panel under it
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: previewCol.implicitHeight
                color: root.cur.bg ?? Colors.bg
                border.width: Metrics.borderWidth
                border.color: root.cur.border ?? Colors.border

                Column {
                    id: previewCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Metrics.borderWidth

                    Rectangle {
                        width: parent.width
                        height: Math.round(Metrics.fontSize * 2)
                        color: root.cur.bar || root.cur.bg || Colors.bg

                        Rectangle {
                            width: parent.width
                            height: Metrics.borderWidth
                            anchors.bottom: parent.bottom
                            color: root.cur.border ?? Colors.border
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.spacing
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: [["[", "dim"], ["●", "accent"], ["]  1  ", "dim"], ["[2]", "accent"], ["  3  │  ", "dim"], ["kitty — ~/notes", "dim"]]

                                Label {
                                    required property var modelData

                                    text: modelData[0]
                                    color: root.cur[modelData[1]] ?? Colors.fg
                                }
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            text: "2:13 am"
                            color: root.cur.fg ?? Colors.fg
                        }

                        Label {
                            anchors.right: parent.right
                            anchors.rightMargin: Metrics.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: "[72%]  [3]  [>_]"
                            color: root.cur.fg ?? Colors.fg
                        }
                    }

                    // a panel: words, quiet words, the one under the pointer, the chosen, an alert
                    Column {
                        width: parent.width
                        topPadding: Metrics.spacing
                        bottomPadding: Metrics.spacing
                        spacing: 2

                        Label {
                            x: Metrics.spacing
                            text: "text, as it reads"
                            color: root.cur.fg ?? Colors.fg
                        }

                        Label {
                            x: Metrics.spacing
                            text: "quiet text: dates, hints, what's off"
                            color: root.cur.dim ?? Colors.dim
                        }

                        Rectangle {
                            width: parent.width - Metrics.spacing * 2
                            x: Metrics.spacing
                            height: hovered.implicitHeight + 4
                            color: root.cur.hoverFill ?? Colors.hoverFill

                            Label {
                                id: hovered

                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: "under the pointer"
                                color: root.cur.fg ?? Colors.fg
                            }
                        }

                        Row {
                            x: Metrics.spacing
                            spacing: Metrics.spacing * 2

                            Label {
                                text: "> chosen"
                                color: root.cur.accent ?? Colors.accent
                            }

                            Label {
                                text: "! battery 5%"
                                color: root.cur.warn ?? Colors.warn
                            }
                        }
                    }
                }
            }

            // ---- the colors:  background  [##]  #0c0c0c  [pick]
            Repeater {
                model: root.rows

                RowLayout {
                    id: row

                    required property var modelData
                    readonly property string key: modelData[0]
                    readonly property string value: root.cur[key] ?? ""
                    readonly property bool ok: /^#?[0-9a-fA-F]{6}$/.test(hex.text.trim()) || (key === "bar" && hex.text.trim() === "")

                    Layout.fillWidth: true
                    spacing: Metrics.spacing

                    Label {
                        Layout.preferredWidth: Math.round(150 * Metrics.scale)
                        text: row.modelData[1]
                        color: Colors.dim
                    }

                    Rectangle {
                        implicitWidth: Math.round(Metrics.fontSize * 2.4)
                        implicitHeight: Math.round(Metrics.fontSize * 1.2)
                        color: row.value || root.cur.bg || Colors.bg
                        border.width: Metrics.borderWidth
                        border.color: Colors.border
                    }

                    TermInput {
                        id: hex

                        Layout.fillWidth: true
                        prompt: "#"
                        promptColor: row.ok ? Colors.dim : Colors.warn
                        text: row.value.replace(/^#/, "")
                        placeholder: row.key === "bar" ? "the background's" : "rrggbb"
                        onTextChanged: if (input.activeFocus)
                            root.setColor(row.key, text)
                    }

                    BracketButton {
                        visible: Screenshot.canFreeze // hyprpicker is there
                        label: "pick"
                        bordered: false
                        textColor: Colors.dim
                        onClicked: root.pick(row.key)
                    }
                }
            }

            //  the light:  ■ ■ ■ ■ ■ ■ ■ ■ ■
            RowLayout {
                spacing: Metrics.spacing

                Label {
                    Layout.preferredWidth: Math.round(150 * Metrics.scale)
                    text: "a light"
                    color: Colors.dim
                }

                Repeater {
                    model: root.lights

                    Rectangle {
                        required property string modelData

                        implicitWidth: Math.round(Metrics.fontSize * 1.4)
                        implicitHeight: implicitWidth
                        color: modelData
                        border.width: root.cur.accent === modelData ? 2 : Metrics.borderWidth
                        border.color: root.cur.accent === modelData ? Colors.fg : Colors.border

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.put("accent", parent.modelData)
                        }
                    }
                }
            }

            //  [save] [cancel]                       [delete]
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                spacing: Metrics.spacing

                BracketButton {
                    label: "save"
                    textColor: root.nameError || Colors.userError ? Colors.dim : Colors.accent
                    onClicked: root.save()
                }

                BracketButton {
                    label: "cancel"
                    onClicked: root.close()
                }

                Label {
                    Layout.fillWidth: true
                    text: "ctrl+s saves · esc goes back"
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                    elide: Text.ElideRight
                }

                BracketButton {
                    visible: !root.isNew && (!root.kawts || !!Colors.user[root.name])
                    label: root.sure ? `${root.sure}: sure?` : root.kawts ? "reset" : "delete"
                    textColor: Colors.warn
                    onClicked: root.drop()
                }
            }
        }
    }
}
