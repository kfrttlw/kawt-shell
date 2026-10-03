pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../utils/themegen.js" as Gen

// Shares the current theme with other programs. Writes kitty / foot / alacritty / hyprland /
// shell / json snippets to ~/.local/state/kawt/theme/, and on a theme switch also recolors
// open terminals (escape sequences) and reloads Hyprland for the border colors.
// hyprland.lua loads the border colors with dofile() from theme/hyprland_colors.lua (see hypr/kawt.lua).
Singleton {
    id: root

    readonly property string dir: `${Settings.dir}/theme`
    property int queued: 0 // 0 none, 1 quiet, 2 live: a switch that came in while writing

    function apply(live: bool): void {
        if (proc.running) {
            queued = Math.max(queued, live ? 2 : 1);
            return;
        }
        const f = Gen.files(Colors.fullName, Colors.palette);
        const args = ["sh", `${Quickshell.shellDir}/scripts/apply-theme.sh`, dir];
        for (const name in f)
            args.push(name, f[name]);
        if (live && Settings.themeTerminals)
            args.push("@pts", Gen.sequences(Colors.palette));
        if (live && Hypr.lua)
            args.push("@hyprreload", "");
        proc.command = args;
        proc.running = true;
    }

    Component.onCompleted: apply(false)

    Connections {
        target: Colors

        function onPaletteChanged(): void {
            root.apply(true);
        }
    }

    Process {
        id: proc

        onExited: {
            if (root.queued > 0) {
                const live = root.queued === 2;
                root.queued = 0;
                root.apply(live);
            }
        }
    }
}
