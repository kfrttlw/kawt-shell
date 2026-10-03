-- kawt-shell for Hyprland 0.55+ (Lua config).
--
-- install: add this line to the end of ~/.config/hypr/hyprland.lua
--   dofile(os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/kawt.lua")
-- It loads this file straight from the kawt folder, so updates to kawt need no copying.
--
-- The launcher sits on SUPER + SPACE (where rofi usually is) and SUPER + R opens it in
-- run mode: comment out your own SUPER + SPACE / SUPER + R lines, otherwise both fire.

local kawt = "qs -c kawt-shell ipc call kawt "
local mod = "SUPER"

-- start the shell with Hyprland
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c kawt-shell")
end)

hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(kawt .. "toggle launcher")) -- rofi-style launcher
hl.bind(mod .. " + R", hl.dsp.exec_cmd(kawt .. "run")) -- launcher in run mode, like windows' win+r
hl.bind(mod .. " + D", hl.dsp.exec_cmd(kawt .. "toggle dock")) -- pinned apps
hl.bind(mod .. " + A", hl.dsp.exec_cmd(kawt .. "sidebar")) -- local ai
hl.bind(mod .. " + W", hl.dsp.exec_cmd(kawt .. "toggle style")) -- wallpaper & themes
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(kawt .. "toggleLight")) -- dark <-> light
hl.bind(mod .. " + N", hl.dsp.exec_cmd(kawt .. "toggle notifs")) -- notification log
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(kawt .. "dnd")) -- do not disturb
hl.bind(mod .. " + I", hl.dsp.exec_cmd(kawt .. "toggle profile")) -- sys / top / notes / cfg

-- kawt animates its panels itself
hl.layer_rule({
    name = "kawt-no-anim",
    match = { namespace = "^kawt-(popover|launcher|style|toasts|sidebar)$" },
    no_anim = true,
})

-- Border and shadow colors of the current kawt theme. kawt rewrites this file and reloads
-- Hyprland on every theme switch. This file is loaded last, so it wins over earlier colors;
-- pcall keeps the config working before kawt has written the file the first time.
local ok, colors = pcall(dofile, os.getenv("HOME") .. "/.local/state/kawt/theme/hyprland_colors.lua")
if ok and type(colors) == "table" then
    hl.config({
        general = {
            col = {
                active_border = colors.m_active,
                inactive_border = colors.m_inactive,
            },
        },
        decoration = {
            shadow = { color = colors.m_shadow },
        },
    })
end
