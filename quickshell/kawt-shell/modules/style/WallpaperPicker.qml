import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// The wallpapers in two panes: the folder's pictures on the left, the one picked big on the right,
// as it would look (dithered in the theme's tones when that's on: Wallpapers.makePreview)
//
//   ┌──────────────────────────┬───────────────────────────────────────────────┐
//   │ ▣ > sunset.jpg         * │ ┌───────────────────────────────────────────┐ │
//   │ ▣   city-night.png       │ │                                           │ │
//   │ ▣   forest.jpg           │ │              the picked one               │ │
//   │ ...                      │ │                                           │ │
//   │                          │ └───────────────────────────────────────────┘ │
//   │                          │ sunset.jpg · on now       [set] [random]      │
//   └──────────────────────────┴───────────────────────────────────────────────┘
// ↑↓ (or j k) pick, enter sets it, r a random one. * marks the one on screen now
RowLayout {
    id: root

    property bool active: true // the style window is open: previews only then
    property int current: 0
    readonly property string picked: Wallpapers.files[current] ?? ""
    readonly property int rowHeight: Math.round(Metrics.fontSize * 2.6)
    readonly property int rows: 9

    spacing: Metrics.padding

    function move(by: int): void {
        if (Wallpapers.files.length === 0)
            return;
        current = Math.max(0, Math.min(Wallpapers.files.length - 1, current + by));
        list.positionViewAtIndex(current, ListView.Contain);
    }

    function setPicked(): void {
        if (picked)
            Wallpapers.set(picked);
    }

    function random(): void {
        Wallpapers.pick("random");
        current = Math.max(0, Wallpapers.files.indexOf(Settings.wallpaper));
        list.positionViewAtIndex(current, ListView.Contain);
    }

    // on opening: the one on screen picked
    function reset(): void {
        current = Math.max(0, Wallpapers.files.indexOf(Settings.wallpaper));
        list.positionViewAtIndex(current, ListView.Center);
    }

    // a moment after the pick stops moving: the preview made for it
    onPickedChanged: previewSoon.restart()

    Timer {
        id: previewSoon

        interval: 180
        onTriggered: Wallpapers.makePreview(root.active ? root.picked : "")
    }

    onActiveChanged: previewSoon.restart()
    Component.onCompleted: previewSoon.restart()
    Component.onDestruction: Wallpapers.makePreview("")

    // ---- the folder
    ListView {
        id: list

        Layout.preferredWidth: Math.round(Metrics.fontSize * 22)
        Layout.preferredHeight: root.rows * root.rowHeight
        Layout.alignment: Qt.AlignTop
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        model: ScriptModel {
            values: Wallpapers.files
        }

        delegate: Item {
            id: row

            required property string modelData
            required property int index
            readonly property bool picked: index === root.current
            readonly property bool onScreen: Settings.wallpaper === modelData
            property bool thumbMissing: false

            width: list.width
            height: root.rowHeight

            Rectangle {
                anchors.fill: parent
                visible: row.picked || rowArea.containsMouse
                color: Colors.hoverFill
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 6
                spacing: Metrics.spacing

                // a tiny copy from the thumbnail cache (the picture itself until it exists)
                Rectangle {
                    Layout.preferredWidth: Math.round((root.rowHeight - 6) * 16 / 9)
                    Layout.preferredHeight: root.rowHeight - 6
                    color: Colors.bg
                    border.width: 1
                    border.color: row.onScreen ? Colors.accent : Colors.border

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: row.thumbMissing ? `file://${row.modelData}` : `file://${Wallpapers.thumb(row.modelData)}?v=${Wallpapers.thumbsVersion}`
                        sourceSize.width: 160
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        onStatusChanged: if (status === Image.Error && !row.thumbMissing)
                            row.thumbMissing = true
                    }
                }

                Label {
                    text: row.picked ? ">" : " "
                    color: Colors.accent
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: Wallpapers.fileName(row.modelData)
                    color: row.onScreen ? Colors.accent : row.picked ? Colors.fg : Colors.dim
                }

                Label {
                    visible: row.onScreen
                    text: "*"
                    color: Colors.accent
                }
            }

            Connections {
                target: Wallpapers

                function onThumbsVersionChanged(): void {
                    row.thumbMissing = false;
                }
            }

            // a click picks it, a second click (or a double one) sets it
            MouseArea {
                id: rowArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (row.picked)
                        root.setPicked();
                    root.current = row.index;
                }
                onDoubleClicked: root.setPicked()
            }
        }
    }

    Rectangle {
        Layout.fillHeight: true
        implicitWidth: Metrics.borderWidth
        color: Colors.border
    }

    // ---- the picked one, big
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Metrics.spacing

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(width * 9 / 16)
            color: Colors.bg
            border.width: 1
            border.color: Settings.wallpaper === root.picked ? Colors.accent : Colors.border

            Image {
                id: big

                anchors.fill: parent
                anchors.margins: 1
                source: Wallpapers.preview ? `file://${Wallpapers.preview}` : ""
                sourceSize.width: 960
                fillMode: Image.PreserveAspectCrop
                smooth: !Settings.wallDither // the dots stay sharp
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: big.status !== Image.Ready
                text: root.picked ? (Settings.wallDither ? "dithering..." : "...") : "-- no picture --"
                color: Colors.dim
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                text: root.picked ? Wallpapers.fileName(root.picked) + (Settings.wallpaper === root.picked ? " · on now" : "") : ""
                color: Settings.wallpaper === root.picked ? Colors.accent : Colors.fg
            }

            BracketButton {
                visible: root.picked !== ""
                label: "set"
                textColor: Settings.wallpaper === root.picked ? Colors.dim : Colors.accent
                onClicked: root.setPicked()
            }

            BracketButton {
                visible: Wallpapers.files.length > 1
                label: "random"
                onClicked: root.random()
            }
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: `${Wallpapers.files.length} in ${Settings.wallpaperDir} · ↑↓ pick · enter set · r random`
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
        }
    }
}
