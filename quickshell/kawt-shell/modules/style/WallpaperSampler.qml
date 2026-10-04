import QtQuick
import qs.config
import "../../utils/wallpalette.js" as WallPalette

// Reads the wallpaper's colors into Settings.wallPalette (the "wallpaper" theme), whenever
// the wallpaper differs from the one the palette was made from. The image is drawn tiny
// into a canvas only to read its pixels; it's never seen (opacity 0, but still painted:
// a canvas that isn't visible doesn't paint at all).
Item {
    id: root

    readonly property string wanted: Settings.wallpaper !== "" && Settings.wallPalette?.source !== Settings.wallpaper ? Settings.wallpaper : ""

    width: canvas.width
    height: canvas.height
    opacity: 0

    Image {
        id: picture

        visible: false
        source: root.wanted ? `file://${root.wanted}` : ""
        asynchronous: true
        sourceSize.width: 96
        onStatusChanged: if (status === Image.Ready)
            canvas.requestPaint()
    }

    Canvas {
        id: canvas

        width: 48
        height: 27

        onPaint: {
            if (picture.status !== Image.Ready || !root.wanted)
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(picture, 0, 0, width, height);
            const p = WallPalette.palette(ctx.getImageData(0, 0, width, height).data);
            Settings.wallPalette = { source: root.wanted, dark: p.dark, light: p.light };
        }
    }
}
