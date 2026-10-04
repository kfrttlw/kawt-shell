import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Themes (with color swatches) and a wallpaper grid. Picking a theme also recolors
// terminals and writes configs for other apps (services/ThemeExport.qml).
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("style", forScreen)

    screen: forScreen
    visible: open
    color: "transparent"

    WlrLayershell.namespace: "kawt-style"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    onOpenChanged: if (open) {
        grid.currentIndex = Math.max(0, Wallpapers.files.indexOf(Settings.wallpaper));
        Wallpapers.refresh();
        box.forceActiveFocus();
        fadeIn.restart();
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

        // arrows walk the wallpapers, enter sets the selected one; [ and ] cycle the themes,
        // t flips dark/light
        Keys.onEscapePressed: Panels.close()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left)
                grid.moveCurrentIndexLeft();
            else if (event.key === Qt.Key_Right)
                grid.moveCurrentIndexRight();
            else if (event.key === Qt.Key_Up)
                grid.moveCurrentIndexUp();
            else if (event.key === Qt.Key_Down)
                grid.moveCurrentIndexDown();
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && grid.count > 0)
                Wallpapers.set(Wallpapers.files[grid.currentIndex]);
            else if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BracketRight) {
                const i = Colors.names.indexOf(Colors.mode) + (event.key === Qt.Key_BracketRight ? 1 : -1);
                Settings.theme = Colors.names[(i + Colors.names.length) % Colors.names.length];
            } else if (event.key === Qt.Key_T)
                Settings.light = !Settings.light;
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

                // [dark] light   (super+shift+w)
                Repeater {
                    model: ["dark", "light"]

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
                    model: Colors.names

                    // a tiny preview drawn in the theme's own colors
                    Rectangle {
                        id: tile

                        required property string modelData
                        readonly property var t: Colors.preview(modelData)
                        readonly property bool current: Colors.mode === modelData

                        width: 132
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
                                text: (tile.current ? "> " : "") + tile.modelData
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

                        MouseArea {
                            id: tileArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.theme = tile.modelData
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                // soft: muted, crt: bright like an old monitor
                Label {
                    text: "terminal:"
                    color: Colors.dim
                }

                Repeater {
                    model: ["soft", "crt"]

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

            // --------------------------------------------------------- wallpaper
            Label {
                Layout.topMargin: Metrics.spacing
                text: `-- wallpaper${Wallpapers.backend && Wallpapers.backend !== "kawt" ? ` (via ${Wallpapers.backend})` : ""} --`
                color: Colors.dim
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

            Label {
                visible: !Wallpapers.loading && Wallpapers.files.length === 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: `-- no images in ${Settings.wallpaperDir} --\nput some .jpg/.png there, or type another folder above and press enter`
                color: Colors.dim
            }

            Label {
                Layout.alignment: Qt.AlignRight
                visible: grid.count > 0
                text: "←↑↓→ pick · enter set · [ ] theme · t dark/light"
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 3
            }

            GridView {
                id: grid

                readonly property int columns: Math.max(2, Math.floor(width / 200))

                Layout.fillWidth: true
                implicitHeight: Math.min(3, Math.ceil(count / columns)) * cellHeight
                visible: count > 0
                clip: true
                cellWidth: Math.floor(width / columns)
                cellHeight: Math.round((cellWidth - 8) * 9 / 16) + Metrics.fontSize + 16
                boundsBehavior: Flickable.StopAtBounds
                model: Wallpapers.files

                delegate: Item {
                    id: thumb

                    required property string modelData
                    required property int index
                    readonly property bool current: Settings.wallpaper === modelData
                    readonly property bool selected: GridView.isCurrentItem && box.activeFocus

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        id: frame

                        x: 4
                        y: 4
                        width: parent.width - 8
                        height: Math.round(width * 9 / 16)
                        color: Colors.hoverFill
                        // set wallpaper: accent; keyboard cursor: thick fg frame; hover: dim
                        border.width: thumb.current || thumb.selected ? 2 : 1
                        border.color: thumb.current ? Colors.accent : thumb.selected ? Colors.fg : thumbArea.containsMouse ? Colors.dim : Colors.border

                        Image {
                            anchors.fill: parent
                            anchors.margins: frame.border.width
                            source: `file://${thumb.modelData}`
                            sourceSize.width: 320
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                    }

                    Label {
                        anchors.top: frame.bottom
                        anchors.topMargin: 2
                        x: frame.x
                        width: frame.width
                        elide: Text.ElideMiddle
                        text: (thumb.current ? "> " : "") + Wallpapers.fileName(thumb.modelData)
                        color: thumb.current ? Colors.accent : Colors.dim
                        font.pixelSize: Metrics.fontSize - 2
                    }

                    MouseArea {
                        id: thumbArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            grid.currentIndex = thumb.index;
                            box.forceActiveFocus();
                            Wallpapers.set(thumb.modelData);
                        }
                    }
                }
            }
        }
    }
}
