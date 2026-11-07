import QtQuick
import qs.config

// kawt's red block, the one after its name in the logo, small: a few bars one over the other.
// How it lights says what's going on:
//   run    they light one after another from the top, stay a moment, go out, again
//   scan   one lit bar going down and up (the model thinking)
//   wait   all of them blinking slowly: something waits for you
//   done   still, in the dim color          error  still, in the warning color
//   idle   still, in the line color      lit    still, all in the light (the start button)
// The timer runs only while it moves and is seen.
Column {
    id: root

    property string mode: "idle"
    property int count: 3
    property int barWidth: Math.round(Metrics.fontSize * 0.75)
    property int barHeight: Math.max(2, Math.round(Metrics.fontSize * 0.16))
    property int phase: 0

    spacing: barHeight

    function lit(i: int): bool {
        if (mode === "run")
            return i < phase % (count + 2);
        if (mode === "scan") {
            const p = phase % Math.max(1, 2 * count - 2);
            return i === (p < count ? p : 2 * count - 2 - p);
        }
        return mode === "lit" || (mode === "wait" && phase % 2 === 0);
    }

    onModeChanged: phase = 0

    Timer {
        running: (root.mode === "run" || root.mode === "scan" || root.mode === "wait") && root.visible
        repeat: true
        interval: root.mode === "wait" ? 530 : root.mode === "scan" ? 90 : 120
        onTriggered: root.phase++
    }

    Repeater {
        model: root.count

        Rectangle {
            required property int index

            width: root.barWidth
            height: root.barHeight
            // phase in the binding: it's read again on every tick
            color: root.phase >= 0 && root.lit(index) ? Colors.accent : root.mode === "error" ? Colors.warn : root.mode === "done" ? Colors.dim : Colors.border
        }
    }
}
