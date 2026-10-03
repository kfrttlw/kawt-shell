-- kawt-shell for Hyprland 0.55+ (Lua config).
--
-- install: add this line to the end of ~/.config/hypr/hyprland.lua
--   pcall(dofile, os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/kawt.lua")
-- (pcall: if kawt is missing or broken, Hyprland just skips it instead of failing)
-- It loads this file straight from the kawt folder, so updates to kawt need no copying.
--
-- The launcher sits on SUPER + SPACE (where rofi usually is) and SUPER + R opens it in
-- run mode: comment out your own SUPER + SPACE / SUPER + R lines, otherwise both fire.

local kawt = "qs -c kawt-shell ipc call kawt "
local mod = "SUPER"

-- Every part runs in its own pcall: if something here doesn't fit your Hyprland version,
-- only that part is skipped, the rest of your config keeps working.
local function try(what, fn)
    local ok, err = pcall(fn)
    if not ok then
        print("kawt.lua: " .. what .. " skipped: " .. tostring(err))
    end
end

-- start the shell with Hyprland
try("autostart", function()
    hl.on("hyprland.start", function()
        hl.exec_cmd("qs -c kawt-shell")
    end)
end)

try("binds", function()
    hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(kawt .. "toggle launcher")) -- rofi-style launcher
    hl.bind(mod .. " + R", hl.dsp.exec_cmd(kawt .. "run")) -- launcher in run mode, like windows' win+r
    hl.bind(mod .. " + D", hl.dsp.exec_cmd(kawt .. "toggle dock")) -- pinned apps
    hl.bind(mod .. " + A", hl.dsp.exec_cmd(kawt .. "sidebar")) -- local ai
    hl.bind(mod .. " + W", hl.dsp.exec_cmd(kawt .. "toggle style")) -- wallpaper & themes
    hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(kawt .. "toggleLight")) -- dark <-> light
    hl.bind(mod .. " + N", hl.dsp.exec_cmd(kawt .. "toggle notifs")) -- notification log
    hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(kawt .. "dnd")) -- do not disturb
    hl.bind(mod .. " + I", hl.dsp.exec_cmd(kawt .. "toggle profile")) -- sys / top / notes / cfg
    -- kawt's own lock screen. try it once by hand first (qs -c kawt-shell ipc call kawt lock),
    -- then it can replace hyprlock on super + l
    hl.bind(mod .. " + SHIFT + L", hl.dsp.exec_cmd(kawt .. "lock"))
end)

-- the kawt look: square windows, like the bar. kawt.lua is loaded last, so this wins over
-- the rounding in hyprland.lua; delete this block to keep your own.
-- allow_session_lock_restore: if the kawt lock screen ever crashes, restarting quickshell
-- (from a tty: qs -c kawt-shell -d) brings it back instead of leaving the screen stuck.
try("look", function()
    hl.config({
        decoration = { rounding = 0 },
        misc = { allow_session_lock_restore = true },
    })
end)

-- kawt animates its panels itself
try("layer rule", function()
    hl.layer_rule({
        name = "kawt-no-anim",
        match = { namespace = "^kawt-(popover|launcher|style|toasts|sidebar|osd)$" },
        no_anim = true,
    })
end)

-- Border and shadow colors of the current kawt theme. kawt rewrites this file and reloads
-- Hyprland on every theme switch. This file is loaded last, so it wins over earlier colors.
try("theme colors", function()
    local colors = dofile(os.getenv("HOME") .. "/.local/state/kawt/theme/hyprland_colors.lua")
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
end)
