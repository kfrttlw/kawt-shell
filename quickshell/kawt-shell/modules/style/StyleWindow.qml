import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Wallpaper and theme (super + w), like an old system's display properties: a real window
// (components/AppWindow.qml) in three tabs.
//   Wallpaper  the picked one big across the top, with a little bar in the theme over it; the
//              folder's pictures in a grid under it; Browse…, Random, how it's shown
//   Theme      the themes, a small picture of each in its own colors; dark or light; your own
//              (New… / Edit…: ThemeEditor.qml over the window); the terminals' colors, fastfetch
//   Change     a new one every 15 min … 3 h, in order or at random, how it changes
// OK sets the picked one and closes, Apply sets it, Cancel puts back what was on when it opened
// (the wallpaper, the theme, dark or light). Keys: arrows pick, enter sets, r random, t dark /
// light, esc closes (as Cancel).
AppWindow {
    id: root

    property int current: 0 // the wallpaper picked in the grid
    readonly property string picked: Wallpapers.files[current] ?? ""
    property var before: ({}) // what was on when it opened: Cancel goes back to it
    property bool browsing: false // the folder line is open
    property int roomHeight: 1080 // the screen it opened on: looked at once, so it doesn't jump

    name: "style"
    icon: "wallpaper"
    title: Strings.t("styleTitle")
    bodyWidth: Math.round(640 * Metrics.scale)
    // room for the picture across the tab and two rows of the grid; less on a small screen
    bodyHeight: Math.min(Math.round(690 * Metrics.scale), roomHeight - Metrics.barHeight - 140)
    // off the screen while a color is picked off it (the theme editor)
    visible: !editor.picking

    function name_(path: string): string {
        return path.split("/").pop().replace(/\.[^.]+$/, "");
    }

    function move(by: int): void {
        if (Wallpapers.files.length === 0)
            return;
        current = Math.max(0, Math.min(Wallpapers.files.length - 1, current + by));
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    function apply(): void {
        if (picked && picked !== Settings.wallpaper)
            Wallpapers.set(picked);
    }

    function cancel(): void {
        if (before.wallpaper !== undefined) {
            if (Settings.theme !== before.theme)
                Settings.theme = before.theme;
            if (Settings.light !== before.light)
                Settings.light = before.light;
            if (Settings.wallDither !== before.dither)
                Settings.wallDither = before.dither;
            if (Settings.wallpaper !== before.wallpaper)
                Wallpapers.set(before.wallpaper);
        }
        close();
    }

    function random(): void {
        Wallpapers.pick("random");
        current = Math.max(0, Wallpapers.files.indexOf(Settings.wallpaper));
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    // a moment after the pick stops moving: the preview made for it
    onPickedChanged: previewSoon.restart()

    Timer {
        id: previewSoon

        interval: 180
        onTriggered: Wallpapers.makePreview(root.picked)
    }

    // a tab by name ("wall", "theme", "change"), asked for from outside
    function showTab(name: string): void {
        const i = ["wall", "theme", "change"].indexOf(name);
        if (i >= 0)
            tabs.current = i;
        Panels.styleTab = "";
    }

    Component.onCompleted: {
        roomHeight = Quickshell.screens.find(s => s.name === Panels.focusedScreen)?.height ?? 1080;
        showTab(Panels.styleTab);
        before = { wallpaper: Settings.wallpaper, theme: Settings.theme, light: Settings.light, dither: Settings.wallDither };
        Wallpapers.refresh();
        current = Math.max(0, Wallpapers.files.indexOf(Settings.wallpaper));
        previewSoon.restart();
        keys.forceActiveFocus();
        // "Own theme…" in the settings: straight into the editor, on the theme tab
        if (Panels.styleEdit !== "") {
            tabs.current = 1;
            if (Panels.styleEdit === "new")
                editor.openNew();
            else
                editor.openEdit();
            Panels.styleEdit = "";
        }
    }
    Component.onDestruction: Wallpapers.makePreview("")

    // "Own theme…" while it's open already
    Connections {
        target: Panels

        function onStyleTabChanged(): void {
            root.showTab(Panels.styleTab);
        }

        function onStyleEditChanged(): void {
            if (Panels.styleEdit === "")
                return;
            tabs.current = 1;
            if (Panels.styleEdit === "new")
                editor.openNew();
            else
                editor.openEdit();
            Panels.styleEdit = "";
        }
    }

    Connections {
        target: Wallpapers

        // the folder read again: the one on screen picked
        function onFilesChanged(): void {
            root.current = Math.max(0, Wallpapers.files.indexOf(Settings.wallpaper));
        }
    }

    // keeps the "wallpaper" theme in step with the chosen wallpaper
    WallpaperSampler {
        x: 0
        y: 0
    }

    Item {
        id: keys

        focus: true
        Keys.onEscapePressed: root.cancel()
        Keys.onPressed: event => {
            const across = 3;
            if (event.key === Qt.Key_Left)
                root.move(-1);
            else if (event.key === Qt.Key_Right)
                root.move(1);
            else if (event.key === Qt.Key_Up)
                root.move(-across);
            else if (event.key === Qt.Key_Down)
                root.move(across);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.apply();
            else if (event.key === Qt.Key_R)
                root.random();
            else if (event.key === Qt.Key_T)
                Settings.light = !Settings.light;
            else
                return;
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: keys.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacing

        Tabs {
            id: tabs

            tabs: [Strings.t("tab_wall"), Strings.t("tab_theme"), Strings.t("tab_change")]
        }

        // ---------------------------------------------------------------- wallpaper
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: tabs.current === 0
            spacing: Metrics.spacing

            // the picked one big, across the tab, sunk in a frame, a little bar in the theme over it
            Rectangle {
                id: preview

                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Math.min(width * 9 / 16, root.bodyHeight * 0.48))
                color: Colors.bg

                Bevel {
                    style: "sunk"
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: Wallpapers.preview ? `file://${Wallpapers.preview}` : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: !Settings.wallDither
                }

                Label {
                    anchors.centerIn: parent
                    visible: root.picked === ""
                    text: Strings.t("noWallpaper")
                    color: Colors.dim
                }

                // the bar, in small: kawt's button, two windows, the desks, the clock
                Rectangle {
                    id: miniBar

                    x: 2
                    y: Metrics.barBottom ? parent.height - 2 - height : 2
                    width: parent.width - 4
                    height: Metrics.fontSize + 7
                    color: Colors.face

                    Bevel {
                        style: "raised"
                    }

                    Row {
                        x: 3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Rectangle {
                            width: 30
                            height: miniBar.height - 6
                            color: Colors.face

                            Bevel {
                                style: "raised"
                            }

                            Rectangle {
                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4
                                height: parent.height - 6
                                color: Colors.accent
                            }
                        }

                        Repeater {
                            model: [70, 54]

                            Rectangle {
                                required property int modelData
                                required property int index

                                width: modelData
                                height: miniBar.height - 6
                                color: Colors.face

                                Bevel {
                                    style: parent.index === 0 ? "pressed" : "raised"
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Repeater {
                            model: 4

                            Rectangle {
                                required property int index

                                anchors.verticalCenter: parent.verticalCenter
                                width: 9
                                height: 9
                                color: index === 1 ? Colors.accent : "transparent"
                                border.width: 1
                                border.color: index === 1 ? Colors.accent : Colors.dim
                            }
                        }

                        Label {
                            leftPadding: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: Time.fmt(Time.now)
                        }
                    }
                }
            }

            // its name, and whether it's on now
            Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                visible: root.picked !== ""
                text: `${root.picked.split("/").pop()} · ${root.picked === Settings.wallpaper ? Strings.t("wallOnNow") : Strings.t("wallApplyToSet")}`
                color: root.picked === Settings.wallpaper ? Colors.fg : Colors.dim
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                text: `${Settings.wallpaperDir.replace(Quickshell.env("HOME"), "~")} · ${Wallpapers.files.length}`
                color: Colors.dim
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Metrics.padding

                // the pictures, sunk in a field: three in a row, the picked one red
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Colors.well

                    Bevel {
                        style: "sunk"
                    }

                    Label {
                        anchors.centerIn: parent
                        width: parent.width - 20
                        visible: !Wallpapers.loading && Wallpapers.files.length === 0
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        text: Strings.t("noPictures")
                        color: Colors.dim
                    }

                    GridView {
                        id: grid

                        x: 3
                        y: 3
                        width: parent.width - 6
                        height: parent.height - 6
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        cellWidth: Math.floor(width / 3)
                        cellHeight: Math.round(cellWidth * 9 / 16) + Metrics.fontSize + 12
                        model: ScriptModel {
                            values: Wallpapers.files
                        }

                        delegate: Rectangle {
                            id: cell

                            required property string modelData
                            required property int index
                            readonly property bool isPicked: index === root.current
                            property bool thumbMissing: false

                            width: grid.cellWidth
                            height: grid.cellHeight
                            color: isPicked ? Colors.accent : "transparent"

                            Image {
                                x: 4
                                y: 4
                                width: parent.width - 8
                                height: Math.round(width * 9 / 16)
                                source: cell.thumbMissing ? `file://${cell.modelData}` : `file://${Wallpapers.thumb(cell.modelData)}?v=${Wallpapers.thumbsVersion}`
                                sourceSize.width: 200
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                onStatusChanged: if (status === Image.Error && !cell.thumbMissing)
                                    cell.thumbMissing = true
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                width: parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: root.name_(cell.modelData)
                                color: cell.isPicked ? Colors.onAccent : Settings.wallpaper === cell.modelData ? Colors.accent : Colors.fg
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.current = cell.index;
                                    keys.forceActiveFocus();
                                }
                                onDoubleClicked: root.apply()
                            }
                        }
                    }
                }

                // what to do with them
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: false // its buttons fill it, it doesn't fill the row
                    Layout.preferredWidth: Math.round(170 * Metrics.scale)
                    spacing: 6

                    PushButton {
                        Layout.fillWidth: true
                        text: Strings.t("browse")
                        active: root.browsing
                        onClicked: {
                            root.browsing = !root.browsing;
                            if (root.browsing)
                                folder.input.forceActiveFocus();
                        }
                    }

                    PushButton {
                        Layout.fillWidth: true
                        text: Strings.t("randomWall")
                        onClicked: root.random()
                    }

                    PushButton {
                        Layout.fillWidth: true
                        text: Strings.t("noWallpaper")
                        active: Settings.wallpaper === ""
                        onClicked: Wallpapers.set("")
                    }

                    Label {
                        Layout.topMargin: 6
                        text: Strings.t("wallShown")
                        color: Colors.dim
                    }

                    Check {
                        radio: true
                        text: Strings.t("wallDithered")
                        checked: Settings.wallDither
                        onToggled: Settings.wallDither = true
                    }

                    Check {
                        radio: true
                        text: Strings.t("wallAsIs")
                        checked: !Settings.wallDither
                        onToggled: Settings.wallDither = false
                    }
                }
            }

            // Browse…: the folder they come from
            TermInput {
                id: folder

                Layout.fillWidth: true
                visible: root.browsing
                prompt: Strings.t("folderPrompt")
                text: Settings.wallpaperDir
                onAccepted: t => {
                    Settings.wallpaperDir = t.trim() || Settings.wallpaperDir;
                    Wallpapers.refresh();
                    root.browsing = false;
                    keys.forceActiveFocus();
                }
                Keys.onEscapePressed: {
                    root.browsing = false;
                    keys.forceActiveFocus();
                }
            }
        }

        // ---------------------------------------------------------------- theme
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: tabs.current === 1
            spacing: Metrics.spacing

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: Colors.choices

                    // a small picture drawn in the theme's own colors: its bar, its words, its light
                    Rectangle {
                        id: tile

                        required property var modelData
                        readonly property var t: Colors.themes[modelData.theme][modelData.light === null ? Colors.variant : modelData.light ? "light" : "dark"]
                        readonly property bool isCurrent: Colors.isCurrent(modelData)

                        width: Math.round(140 * Metrics.scale)
                        height: tileCol.implicitHeight + 10
                        color: isCurrent ? Colors.accent : tileArea.containsMouse ? Colors.hoverFill : "transparent"

                        Column {
                            id: tileCol

                            x: 5
                            y: 5
                            width: parent.width - 10
                            spacing: 4

                            Rectangle {
                                width: parent.width
                                height: Math.round(width * 0.45)
                                color: tile.t.bg
                                border.width: 1
                                border.color: Colors.deep

                                Rectangle {
                                    x: 1
                                    y: 1
                                    width: parent.width - 2
                                    height: 6
                                    color: tile.t.bar ?? tile.t.bg

                                    Rectangle {
                                        x: 1
                                        y: 1
                                        width: 12
                                        height: 4
                                        color: tile.t.accent
                                    }
                                }

                                Row {
                                    x: 6
                                    y: 14
                                    spacing: 2

                                    Repeater {
                                        model: [tile.t.fg, tile.t.dim, tile.t.border, tile.t.accent, tile.t.warn]

                                        Rectangle {
                                            required property string modelData

                                            width: 12
                                            height: 8
                                            color: modelData
                                        }
                                    }
                                }
                            }

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                // kawt's own by their names in the window (black: Graphite), yours as you named them
                                text: ({ black: Strings.t("graphite"), white: Strings.t("silver"), wallpaper: Strings.t("fromWallpaper") })[tile.modelData.name] ?? tile.modelData.name
                                color: tile.isCurrent ? Colors.onAccent : Colors.fg
                            }
                        }

                        // a click picks it; a right click opens it in the editor too
                        MouseArea {
                            id: tileArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                Colors.choose(tile.modelData);
                                if (mouse.button === Qt.RightButton)
                                    editor.openEdit();
                            }
                        }
                    }
                }
            }

            // dark or light (black and white are that already); the wallpaper theme's strength
            Group {
                title: Strings.t("themeShade")

                RowLayout {
                    spacing: 16

                    Repeater {
                        model: Colors.mode !== "thinkpad" ? [[false, "darkWord"], [true, "lightWord"]] : []

                        Check {
                            required property var modelData

                            radio: true
                            text: Strings.t(modelData[1])
                            checked: Colors.light === modelData[0]
                            onToggled: Settings.light = modelData[0]
                        }
                    }

                    Label {
                        visible: Colors.mode === "thinkpad"
                        text: Strings.t("thinkpadShade")
                        color: Colors.dim
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: Colors.mode === "wallpaper" ? [["calm", "wallCalm"], ["strong", "wallStrong"], ["full", "wallFull"]] : []

                        Check {
                            required property var modelData

                            radio: true
                            text: Strings.t(modelData[1])
                            checked: Settings.wallStrength === modelData[0]
                            onToggled: Settings.wallStrength = modelData[0]
                        }
                    }
                }
            }

            // your own: config/Colors.qml says how; or what's wrong with the file
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: Colors.userError || Strings.t("ownThemesNote")
                    color: Colors.userError ? Colors.warn : Colors.dim
                }

                PushButton {
                    minWidth: 0
                    text: Strings.t("themeNew")
                    onClicked: editor.openNew()
                }

                PushButton {
                    minWidth: 0
                    text: Colors.mode === "wallpaper" ? Strings.t("themeEditCopy") : Strings.t("themeEdit")
                    onClicked: editor.openEdit()
                }
            }

            // the terminals: calm to bright
            Group {
                title: Strings.t("terminalsWord")

                RowLayout {
                    spacing: 16

                    Repeater {
                        model: [["crt", "termCrt"], ["soft", "termSoft"], ["vivid", "termVivid"]]

                        Check {
                            required property var modelData

                            radio: true
                            text: Strings.t(modelData[1])
                            checked: Settings.termColors === modelData[0]
                            onToggled: Settings.termColors = modelData[0]
                        }
                    }
                }

                Check {
                    text: Strings.t("recolorTerms")
                    note: "kitty · foot · alacritty · hyprland: ~/.local/state/kawt/theme/"
                    checked: Settings.themeTerminals
                    onToggled: Settings.themeTerminals = !Settings.themeTerminals
                }
            }

            // fastfetch's logo: your system's (in its own colors or the theme's), or kawt's
            Group {
                title: "fastfetch"

                Flow {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: [["distro", "fetchDistro"], ["distro-tinted", "fetchTinted"], ["kawt", "kawt"], ["trackpoint", "trackpoint"], ["stripes", "stripes"], ["picture", "fetchPictureWord"]]

                        Check {
                            required property var modelData

                            radio: true
                            text: modelData[1] === modelData[0] ? modelData[0] : Strings.t(modelData[1])
                            checked: Settings.fetchLogo === modelData[0]
                            onToggled: Settings.fetchLogo = modelData[0]
                        }
                    }
                }

                // the picture: stripes, ~/.face, or a file of yours, in the theme's tones
                RowLayout {
                    Layout.fillWidth: true
                    visible: Settings.fetchLogo === "picture"
                    spacing: 14

                    Repeater {
                        model: [["", "stripes"], ["face", "~/.face"], ["own", "fetchOwnFile"]]

                        Check {
                            required property var modelData
                            readonly property string now: Settings.fetchPicture === "" || Settings.fetchPicture === "face" ? Settings.fetchPicture : "own"

                            radio: true
                            text: modelData[1].startsWith("fetch") ? Strings.t(modelData[1]) : modelData[1]
                            checked: now === modelData[0]
                            onToggled: Settings.fetchPicture = modelData[0] === "own" ? (ownPicture.text.trim() || "~/Pictures/") : modelData[0]
                        }
                    }

                    TermInput {
                        id: ownPicture

                        Layout.fillWidth: true
                        visible: Settings.fetchPicture !== "" && Settings.fetchPicture !== "face"
                        prompt: ""
                        placeholder: "~/Pictures/me.png"
                        Component.onCompleted: text = visible ? Settings.fetchPicture : ""
                        onAccepted: t => Settings.fetchPicture = t.trim() || ""
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: Settings.fetchLogo === "picture"
                    wrapMode: Text.Wrap
                    text: Strings.t("fetchPictureNote")
                    color: Colors.dim
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        // ---------------------------------------------------------------- change
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: tabs.current === 2
            spacing: Metrics.spacing

            Group {
                title: Strings.t("changeEvery")

                Flow {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: [[0, Strings.t("never")], [15, Strings.t("inMin").arg(15)], [30, Strings.t("inMin").arg(30)], [60, Strings.t("inHours").arg(1)], [180, Strings.t("inHours").arg(3)]]

                        Check {
                            required property var modelData

                            radio: true
                            text: modelData[1]
                            checked: Settings.wallpaperEvery === modelData[0]
                            onToggled: Settings.wallpaperEvery = modelData[0]
                        }
                    }
                }
            }

            Group {
                visible: Settings.wallpaperEvery > 0
                title: Strings.t("changeOrder")

                RowLayout {
                    spacing: 16

                    Repeater {
                        model: [["next", "inOrder"], ["random", "atRandom"]]

                        Check {
                            required property var modelData

                            radio: true
                            text: Strings.t(modelData[1])
                            checked: Settings.wallpaperOrder === modelData[0]
                            onToggled: Settings.wallpaperOrder = modelData[0]
                        }
                    }
                }
            }

            // only with awww (swww): without it kawt draws the wallpaper itself, at once
            Group {
                visible: Wallpapers.found === "awww" || Wallpapers.found === "swww"
                title: Strings.t("drawnBy")

                RowLayout {
                    spacing: 16

                    Repeater {
                        model: [["", Wallpapers.found], ["kawt", "kawt"]]

                        Check {
                            required property var modelData

                            radio: true
                            text: modelData[1]
                            checked: Settings.wallpaperBy === modelData[0]
                            onToggled: Settings.wallpaperBy = modelData[0]
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: Wallpapers.backend === "awww" || Wallpapers.backend === "swww"
                    spacing: 14

                    Label {
                        text: Strings.t("transitionWord")
                        color: Colors.dim
                    }

                    Repeater {
                        model: ["crt", "fade", "grow", "random", "none"]

                        Check {
                            required property string modelData

                            radio: true
                            text: modelData
                            checked: Settings.wallpaperTransition === modelData
                            onToggled: Settings.wallpaperTransition = modelData
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Strings.t("styleKeys")
                color: Colors.dim
            }

            Item {
                Layout.fillHeight: true
            }
        }

        // OK · Cancel · Apply
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Item {
                Layout.fillWidth: true
            }

            PushButton {
                text: Strings.t("ok")
                onClicked: {
                    root.apply();
                    root.close();
                }
            }

            PushButton {
                text: Strings.t("cancel")
                onClicked: root.cancel()
            }

            PushButton {
                text: Strings.t("applyWord")
                enabled: root.picked !== "" && root.picked !== Settings.wallpaper
                onClicked: root.apply()
            }
        }
    }

    // over the window: a theme of your own; esc comes back here
    ThemeEditor {
        id: editor

        anchors.fill: parent
        onClosed: keys.forceActiveFocus()
    }
}
