-- ~/.config/hypr/user.lua: your own Hyprland settings, next to kawt's standard config.
-- Loaded last (after hypr/preset.lua and kawt.lua), so whatever you set here wins. The
-- installer wrote this file once and never touches it again: it's yours.
--
--   settings   set them again: hl.config, hl.animation, hl.env... (the last one counts)
--   keys       a key bound twice does both: free the standard one first
--                  preset.unbind("SUPER + B")
--                  hl.bind("SUPER + B", hl.dsp.exec_cmd("chromium")) -- browser
--              (a "-- comment" at the end puts it in kawt's key list, super + /)
--   programs   the standard keys super + q / e / b start these
--
-- What the standard config does: ~/.config/quickshell/kawt-shell/hypr/preset.lua

-- monitors: names and modes with  hyprctl monitors all  (or ~/kawt/install.sh --monitors asks)
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144", position = "0x0", scale = "1" })

preset.terminal = "kitty"
preset.files    = "thunar"
preset.browser  = "firefox"

hl.config({
    input = {
        kb_layout  = "us",
        kb_options = "",
        sensitivity = 0, -- mouse speed, -1.0 .. 1.0
    },
})

-- more, for example:
-- hl.config({ general = { gaps_out = 8 } })
-- hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "kawtOut", style = "popin 80%" })
-- hl.window_rule({ match = { class = "^(firefox|discord)$" }, opacity = "1 0.5" })
-- hl.on("hyprland.start", function() hl.exec_cmd("telegram-desktop -startintray") end)
