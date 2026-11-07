import QtQuick
import qs.config
import qs.services
import "../../utils/wallpalette.js" as WallPalette

// The fallback for the wallpaper theme: services/Wallpapers.qml measures every wallpaper with
// ffmpeg; only if that fails (no ffmpeg) is it done here, while the style window is open.
// The image is drawn tiny into a canvas only to read its pixels; it sits behind the style
// window's card, unseen.
Item {
    id: root

    readonly property string wanted: Wallpapers.unmeasured !== "" && Wallpapers.unmeasured === Wallpapers.failed ? Wallpapers.unmeasured : ""

    width: canvas.width
    height: canvas.height
    // painted for real but hidden behind its parent's own background: a canvas with
    // opacity 0 or visible: false may never paint, and then nothing gets measured
    z: -1

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
            const a = WallPalette.analyse(ctx.getImageData(0, 0, width, height).data);
            Settings.wallPalette = Object.assign({ source: root.wanted, version: Wallpapers.paletteVersion }, a);
        }
    }
}
