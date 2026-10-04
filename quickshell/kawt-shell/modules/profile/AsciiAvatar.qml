import QtQuick
import Quickshell
import qs.config
import qs.components

// ~/.face drawn with characters, like an old terminal printing a photo.
// `available` stays false if there is no such picture (the profile then shows the machine).
Item {
    id: root

    property string source: `file://${Quickshell.env("HOME")}/.face`
    property int cols: 26
    readonly property int rows: Math.round(cols * 0.45) // terminal cells are about twice as tall as wide
    readonly property bool available: art.text !== ""
    // dense characters where the picture is bright (dark theme) or dark (light theme)
    readonly property string ramp: " .:-=+*#%@"

    implicitWidth: art.implicitWidth
    implicitHeight: art.implicitHeight

    Image {
        id: picture

        visible: false
        source: root.source
        asynchronous: true
        sourceSize.width: root.cols * 4
        onStatusChanged: if (status === Image.Ready)
            canvas.requestPaint()
    }

    // only used to read the picture's pixels, never shown
    Canvas {
        id: canvas

        visible: false
        width: root.cols
        height: root.rows

        onPaint: {
            if (picture.status !== Image.Ready)
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(picture, 0, 0, width, height);
            const px = ctx.getImageData(0, 0, width, height).data;
            const n = root.ramp.length - 1;
            let out = "";
            for (let y = 0; y < height; y++) {
                for (let x = 0; x < width; x++) {
                    const i = (y * width + x) * 4;
                    let l = (0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]) / 255;
                    if (Colors.light)
                        l = 1 - l;
                    out += root.ramp[Math.round(l * n)];
                }
                out += y < height - 1 ? "\n" : "";
            }
            art.text = out;
        }
    }

    Connections {
        target: Colors

        function onLightChanged(): void {
            canvas.requestPaint();
        }
    }

    Label {
        id: art

        color: Colors.dim
        lineHeight: 0.9
    }
}
