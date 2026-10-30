import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Themes (with color swatches) and the wallpapers in two panes (WallpaperPicker.qml). Picking a theme also recolors
// terminals and writes configs for other apps (services/ThemeExport.qml). [+ new] and [edit] open
// the theme editor over it (ThemeEditor.qml): your own colors, the bar's among them.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("style", forScreen)

    screen: forScreen
    // off the screen while a color is picked off it
    visible: open && !editor.picking
    color: "transparent"

    WlrLayershell.namespace: "kawt-style"
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
            picker.reset();
            Wallpapers.refresh();
            box.forceActiveFocus();
            fadeIn.restart();
            // [edit] / [+ new] in profile -> cfg: straight into the editor
            if (Panels.styleEdit === "new")
                editor.openNew();
            else if (Panels.styleEdit === "edit")
                editor.openEdit();
            Panels.styleEdit = "";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.close()
        }
    }

    TitledBox {
        id: box

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height * 0.1)
        width: Math.min(860, root.width - Metrics.padding * 2)
        height: body.implicitHeight + Metrics.padding * 2 + titleOverhang
        title: "style"
        hint: "esc"

        // ↑↓ (j k) pick a wallpaper, enter sets it, r a random one; [ and ] walk the themes,
        // t flips dark/light
        Keys.onEscapePressed: Panels.close()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === Qt.Key_Left)
                picker.move(-1);
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Right)
                picker.move(1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                picker.setPicked();
            else if (event.key === Qt.Key_R)
                picker.random();
            else if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BracketRight)
                Colors.step(event.key === Qt.Key_BracketRight ? 1 : -1);
            else if (event.key === Qt.Key_T)
                Settings.light = !Settings.light;
            else if (event.key === Qt.Key_E)
                editor.openEdit();
            else if (event.key === Qt.Key_N)
                editor.openNew();
            else
                return;
            event.accepted = true;
        }

        NumberAnimation {
            id: fadeIn

            target: box
            property: "opacity"
            from: 0
            to: 1
            duration: 120
        }

        MouseArea {
            anchors.fill: parent
            onClicked: box.forceActiveFocus()
        }

        // keeps the "wallpaper" theme in step with the chosen wallpaper
        WallpaperSampler {
            x: 0
            y: 0
        }

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + box.titleOverhang
            spacing: Metrics.spacing

            // ------------------------------------------------------------ themes
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                Label {
                    Layout.fillWidth: true
                    text: "-- theme --"
                    color: Colors.dim
                }

                // the one you're in, in the editor (the wallpaper's: a copy of it, as a new one)
                BracketButton {
                    label: Colors.mode === "wallpaper" ? "edit a copy" : "edit"
                    bordered: false
                    onClicked: editor.openEdit()
                }

                // wallpaper theme strength: [calm] strong full
                Repeater {
                    model: Colors.mode === "wallpaper" ? ["calm", "strong", "full"] : []

                    BracketButton {
                        required property string modelData

                        label: modelData
                        active: Settings.wallStrength === modelData
                        textColor: Settings.wallStrength === modelData ? Colors.accent : Colors.dim
                        bordered: false
                        onClicked: Settings.wallStrength = modelData
                    }
                }

                // [dark] light   (super+shift+w): black and white are that already
                Repeater {
                    model: Colors.mode !== "thinkpad" ? ["dark", "light"] : []

                    BracketButton {
                        required property string modelData

                        label: modelData
                        active: Colors.variant === modelData
                        textColor: Colors.variant === modelData ? Colors.accent : Colors.dim
                        onClicked: Settings.light = modelData === "light"
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                Repeater {
                    model: Colors.choices

                    // a tiny preview drawn in the theme's own colors, its bar on top
                    Rectangle {
                        id: tile

                        required property var modelData
                        readonly property var t: Colors.themes[modelData.theme][modelData.light === null ? Colors.variant : modelData.light ? "light" : "dark"]
                        readonly property bool current: Colors.isCurrent(modelData)

                        width: Math.round(132 * Metrics.scale)
                        height: tileCol.implicitHeight + 12
                        color: t.bg
                        border.width: current ? 2 : 1
                        border.color: current ? Colors.accent : tileArea.containsMouse ? Colors.dim : Colors.border

                        Column {
                            id: tileCol

                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 6
                            spacing: 4

                            Label {
                                text: (tile.current ? "> " : "") + tile.modelData.name
                                color: tile.t.fg
                            }

                            Row {
                                spacing: 2

                                Repeater {
                                    model: [tile.t.fg, tile.t.dim, tile.t.border, tile.t.accent, tile.t.warn]

                                    Rectangle {
                                        required property string modelData

                                        width: 14
                                        height: 8
                                        color: modelData
                                    }
                                }
                            }
                        }

                        // its bar, when it has one of its own
                        Rectangle {
                            visible: !!tile.t.bar
                            width: parent.width - 2
                            height: 3
                            x: 1
                            y: 1
                            color: tile.t.bar ?? "transparent"
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

                // [+ new]: a theme of your own, from the one you're in
                Rectangle {
                    width: Math.round(132 * Metrics.scale)
                    height: newCol.implicitHeight + 12
                    color: newArea.containsMouse ? Colors.hoverFill : "transparent"
                    border.width: 1
                    border.color: newArea.containsMouse ? Colors.dim : Colors.border

                    Column {
                        id: newCol

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 6
                        spacing: 4

                        Label {
                            text: "+ new"
                        }

                        Label {
                            text: "your colors"
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 2
                        }
                    }

                    MouseArea {
                        id: newArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editor.openNew()
                    }
                }
            }

            // your own themes (config/Colors.qml says how), or what's wrong with the file
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Colors.userError || "[+ new] makes one, [edit] (or a right click) changes it · ~/.config/kawt/themes.json"
                color: Colors.userError ? Colors.warn : Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                // calm to bright: crt (monochrome ink), soft (the theme's hues), vivid (colorful)
                Label {
                    text: "terminal:"
                    color: Colors.dim
                }

                Repeater {
                    model: ["crt", "soft", "vivid"]

                    BracketButton {
                        required property string modelData

                        label: modelData
                        active: Settings.termColors === modelData
                        textColor: Settings.termColors === modelData ? Colors.accent : Colors.dim
                        onClicked: Settings.termColors = modelData
                    }
                }

                BracketButton {
                    label: Settings.themeTerminals ? "x" : " "
                    bordered: false
                    onClicked: Settings.themeTerminals = !Settings.themeTerminals
                }

                Label {
                    text: "recolor open terminals"
                }

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: "configs for kitty/foot/alacritty/hyprland: ~/.local/state/kawt/theme/"
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }
            }

            // fastfetch's logo: your system's in the theme's colors, or one of kawt's own
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                Label {
                    text: "fastfetch:"
                    color: Colors.dim
                }

                Repeater {
                    model: [["distro", "distro"], ["kawt", "kawt"], ["trackpoint", "trackpoint"], ["stripes", "stripes"]]

                    BracketButton {
                        required property var modelData

                        label: modelData[1]
                        textColor: Settings.fetchLogo === modelData[0] ? Colors.accent : Colors.dim
                        onClicked: Settings.fetchLogo = modelData[0]
                    }
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Settings.fetchLogo === "distro" ? "your system's logo, in the theme's colors" : Settings.fetchLogo === "stripes" ? "kawt in stripes, above the info" : Settings.fetchLogo === "trackpoint" ? "g h b and the red nub" : "kawt in half blocks"
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }
            }

            // --------------------------------------------------------- wallpaper
            //  -- wallpaper --                          drawn by: [awww] kawt
            RowLayout {
                Layout.topMargin: Metrics.spacing
                Layout.fillWidth: true
                spacing: Metrics.spacing

                Label {
                    Layout.fillWidth: true
                    text: `-- wallpaper${Wallpapers.backend && Wallpapers.backend !== "kawt" ? ` (via ${Wallpapers.backend})` : ""} --`
                    color: Colors.dim
                }

                // only when awww (swww) is there: without it kawt draws it anyway
                Label {
                    visible: Wallpapers.found === "awww" || Wallpapers.found === "swww"
                    text: "drawn by:"
                    color: Colors.dim
                }

                Repeater {
                    model: Wallpapers.found === "awww" || Wallpapers.found === "swww" ? [["", Wallpapers.found], ["kawt", "kawt"]] : []

                    BracketButton {
                        required property var modelData

                        label: modelData[1]
                        active: Settings.wallpaperBy === modelData[0]
                        textColor: Settings.wallpaperBy === modelData[0] ? Colors.accent : Colors.dim
                        bordered: false
                        onClicked: Settings.wallpaperBy = modelData[0]
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                TermInput {
                    Layout.fillWidth: true
                    prompt: "dir>"
                    text: Settings.wallpaperDir
                    onAccepted: t => Settings.wallpaperDir = t.trim() || Settings.wallpaperDir
                }

                BracketButton {
                    label: Wallpapers.loading ? "..." : "reload"
                    onClicked: Wallpapers.refresh()
                }

                BracketButton {
                    label: "none"
                    active: Settings.wallpaper === ""
                    onClicked: Wallpapers.set("")
                }
            }

            //  [dithered] as it is   the picture in the theme's tones, dots like an old screen
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                Label {
                    text: "shown:"
                    color: Colors.dim
                }

                Repeater {
                    model: [[true, "dithered"], [false, "as it is"]]

                    BracketButton {
                        required property var modelData

                        label: modelData[1]
                        textColor: Settings.wallDither === modelData[0] ? Colors.accent : Colors.dim
                        onClicked: Settings.wallDither = modelData[0]
                    }
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Settings.wallDither ? "in the theme's tones, its reds as red dots; made again for every theme" : "the picture as it is"
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }
            }

            //  every [off] 15m 30m 1h 3h   [next] random   ·   crt  fade  grow  random  none
            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                Label {
                    text: "new one every:"
                    color: Colors.dim
                }

                Repeater {
                    model: [[0, "off"], [15, "15m"], [30, "30m"], [60, "1h"], [180, "3h"]]

                    BracketButton {
                        required property var modelData

                        label: modelData[1]
                        active: Settings.wallpaperEvery === modelData[0]
                        textColor: Settings.wallpaperEvery === modelData[0] ? Colors.accent : Colors.dim
                        bordered: false
                        onClicked: Settings.wallpaperEvery = modelData[0]
                    }
                }

                Repeater {
                    model: Settings.wallpaperEvery > 0 ? ["next", "random"] : []

                    BracketButton {
                        required property string modelData

                        label: modelData
                        active: Settings.wallpaperOrder === modelData
                        textColor: Settings.wallpaperOrder === modelData ? Colors.accent : Colors.dim
                        bordered: false
                        onClicked: Settings.wallpaperOrder = modelData
                    }
                }

                Label {
                    visible: Wallpapers.backend === "awww" || Wallpapers.backend === "swww"
                    leftPadding: Metrics.spacing
                    text: "· transition:"
                    color: Colors.dim
                }

                Repeater {
                    model: Wallpapers.backend === "awww" || Wallpapers.backend === "swww" ? ["crt", "fade", "grow", "random", "none"] : []

                    BracketButton {
                        required property string modelData

                        label: modelData
                        active: Settings.wallpaperTransition === modelData
                        textColor: Settings.wallpaperTransition === modelData ? Colors.accent : Colors.dim
                        bordered: false
                        onClicked: Settings.wallpaperTransition = modelData
                    }
                }
            }

            Label {
                visible: !Wallpapers.loading && Wallpapers.files.length === 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: `-- no images in ${Settings.wallpaperDir} --\nput some .jpg/.png there, or type another folder above and press enter`
                color: Colors.dim
            }

            Label {
                Layout.alignment: Qt.AlignRight
                visible: Wallpapers.files.length > 0
                text: "[ ] theme · t dark/light · e edit · n new"
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 3
            }

            WallpaperPicker {
                id: picker

                Layout.fillWidth: true
                active: root.open
                visible: Wallpapers.files.length > 0
            }
        }
    }

    // over the style box: a theme of your own; esc comes back here
    ThemeEditor {
        id: editor

        anchors.fill: parent
        onClosed: box.forceActiveFocus()
    }
}
