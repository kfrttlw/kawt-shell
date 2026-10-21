-- ~/.config/hypr/hyprland.lua: Hyprland with kawt's standard config.
-- Nothing to change here: your own settings go to ~/.config/hypr/user.lua. In this order:
--   preset.lua   kawt's standard config, from the kawt folder (git pull updates it)
--   kawt.lua     kawt's keys and the theme's colors
--   user.lua     yours, last: it wins over both
dofile(os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/preset.lua")
pcall(dofile, os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/kawt.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/user.lua")
