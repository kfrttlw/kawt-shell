pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.utils

// The mouse cursor (settings -> look -> cursor): one of kawt's two, drawn a pixel at a time by
// tools/cursors.py into cursors/ (XCursor themes, x1 to x4, never blurred), or the system's own,
// which kawt then doesn't touch at all.
//   kawt-stripes    cut in kawt's bars, like the logo; busy: the bars run
//   kawt-terminal   the console's: fat pixels, typing on a red block, busy: | / - \
// Picked, it's linked into ~/.local/share/icons and handed to Hyprland, which draws it over every
// window and tells GTK (scripts/cursor.sh); programs started from then on get it in XCURSOR_THEME
// too (hypr/kawt.lua reads it from the theme files, services/ThemeExport.qml). Off again: the
// cursor there was before kawt's comes back (Settings.cursorWas).
Singleton {
    id: root

    readonly property string theme: Settings.cursorStyle === "stripes" || Settings.cursorStyle === "terminal" ? `kawt-${Settings.cursorStyle}` : ""
    readonly property int size: 24 * Math.max(1, Math.min(4, Settings.cursorSize || 1))
    property bool again: false // asked while the last one still ran

    function apply(): void {
        if (job.running) {
            again = true;
            return;
        }
        // never picked (or given back already): the system's stays as it is
        if (!theme && !Settings.cursorWas)
            return;
        job.command = ["sh", `${Quickshell.shellDir}/scripts/cursor.sh`, `${Quickshell.shellDir}/cursors`, theme, String(size), Settings.cursorWas];
        job.running = true;
    }

    // once the settings are read (every start: hyprland gets it again), and after a change: a
    // moment later, so a few changes in a row go as one
    Timer {
        id: soon

        interval: 300
        onTriggered: root.apply()
    }

    Component.onCompleted: if (Settings.loaded)
        soon.restart()

    Connections {
        target: Settings

        function onLoadedChanged(): void {
            if (Settings.loaded)
                soon.restart();
        }

        function onCursorStyleChanged(): void {
            if (Settings.loaded)
                soon.restart();
        }

        function onCursorSizeChanged(): void {
            if (Settings.loaded)
                soon.restart();
        }
    }

    Job {
        id: job

        onDone: (code, out) => {
            const was = (out.match(/^was=(.+)$/m) ?? [])[1];
            if (was)
                Settings.cursorWas = was;
            else if (!root.theme && code === 0)
                Settings.cursorWas = ""; // given back: nothing to keep
            if (root.again) {
                root.again = false;
                root.apply();
            }
        }
    }
}
