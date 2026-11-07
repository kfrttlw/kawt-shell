import QtQuick
import qs.config

// The shadow under kawt's own windows with Settings.frames "bevel": a checker of two-pixel dots
// in the dark edge's color, `depth` px to the right and below, like an old mac's. Only the strips
// that stick out are drawn, and only when the size changes. Hyprland gives the apps' windows a
// solid one (hypr/kawt.lua): this one says the window is kawt's.
// Put it before the frame, with the frame's own size: it moves itself out from under it.
Canvas {
    id: root

    property int depth: 8

    x: depth
    y: depth
    visible: Colors.bevel

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible)
        requestPaint()

    Connections {
        target: Colors

        function onDeepChanged(): void {
            root.requestPaint();
        }
    }

    onPaint: {
        const g = getContext("2d"), w = Math.floor(width), h = Math.floor(height);
        // where the strips start, on even pixels: the dots keep one checker across both
        const sx = Math.max(0, w - depth) & ~1, sy = Math.max(0, h - depth) & ~1;
        g.clearRect(0, 0, width, height);
        g.fillStyle = Colors.deep;
        // the right strip down to the bottom, then the bottom one up to it
        for (let y = 0; y < h; y += 2)
            for (let x = sx; x < w; x += 2)
                if (((x >> 1) + (y >> 1)) % 2 === 0)
                    g.fillRect(x, y, 2, 2);
        for (let y = sy; y < h; y += 2)
            for (let x = 0; x < sx; x += 2)
                if (((x >> 1) + (y >> 1)) % 2 === 0)
                    g.fillRect(x, y, 2, 2);
    }
}
