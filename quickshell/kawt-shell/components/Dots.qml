import QtQuick
import qs.config

// The old systems' dotted fill: every other pixel a second color, like a checkerboard. A pressed
// window button in focus, and (in black, over the screen) what's behind a dialog that wants you.
Canvas {
    id: root

    property color base: Colors.face
    property color dots: Colors.hi

    smooth: false
    antialiasing: false
    onBaseChanged: requestPaint()
    onDotsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (base.a > 0) {
            ctx.fillStyle = base;
            ctx.fillRect(0, 0, width, height);
        }
        ctx.fillStyle = ctx.createPattern(dots, Qt.Dense4Pattern);
        ctx.fillRect(0, 0, width, height);
    }
}
