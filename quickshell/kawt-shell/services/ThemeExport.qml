pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../utils/themegen.js" as Gen

// Shares the current theme with other programs. Writes kitty / foot / alacritty / hyprland /
// gtk / shell / json snippets and kawt's folder icons to ~/.local/state/kawt/theme/, and on a
// theme switch also recolors open terminals (escape sequences) and gtk apps, and reloads
// Hyprland for the border colors.
// hyprland.lua loads the border colors with dofile() from theme/hyprland_colors.lua (see hypr/kawt.lua).
Singleton {
    id: root

    readonly property string dir: `${Settings.dir}/theme`
    property int queued: 0 // 0 none, 1 quiet, 2 live: a switch that came in while writing

    // reload: hyprland reads its config again even without hyprland.lua (lite switched off: the
    // blur, shadows and animations of your own config come back)
    function apply(live: bool, reload: bool): void {
        if (proc.running) {
            queued = Math.max(queued, live ? 2 : 1);
            return;
        }
        const f = Gen.files(Colors.fullName, Colors.palette, Settings.termColors, Settings.fetchLogo, Metrics.fontFamily, Settings.lite);
        const args = ["sh", `${Quickshell.shellDir}/scripts/apply-theme.sh`, dir];
        for (const name in f)
            args.push(name, f[name]);
        if (live && Settings.themeTerminals)
            args.push("@pts", Gen.sequences(Colors.palette, Settings.termColors));
        // gtk apps (only where install.sh linked their gtk.css to kawt's): dark or light, and
        // on a switch the open ones read their colors again
        args.push("@gtk", `${Gen.isLight(Colors.palette) ? "light" : "dark"}${live ? " live" : ""}`);
        if (live && (Hypr.lua || reload))
            args.push("@hyprreload", "");
        else if (live)
            args.push("@hyprkeyword", Gen.hyprKeywords(Colors.palette, Settings.lite));
        proc.command = args;
        proc.running = true;
    }

    Component.onCompleted: apply(false, false)

    Connections {
        target: Settings

        function onTermColorsChanged(): void {
            root.apply(true, false);
        }

        // only fastfetch's file changes: nothing to recolor live
        function onFetchLogoChanged(): void {
            root.apply(false, false);
        }

        // gtk's font: apps started from now on
        function onFontFamilyChanged(): void {
            root.apply(false, false);
        }

        // hyprland's blur, shadows and animations: at once
        function onLiteChanged(): void {
            root.apply(true, !Settings.lite);
        }
    }

    Connections {
        target: Colors

        function onPaletteChanged(): void {
            root.apply(true, false);
        }
    }

    Process {
        id: proc

        onExited: {
            if (root.queued > 0) {
                const live = root.queued === 2;
                root.queued = 0;
                root.apply(live, false);
            }
        }
    }
}
