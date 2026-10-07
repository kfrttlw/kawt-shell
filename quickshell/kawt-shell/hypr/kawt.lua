-- kawt-shell for Hyprland 0.55+ (Lua config).
--
-- install: add this line to the end of ~/.config/hypr/hyprland.lua
--   pcall(dofile, os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/kawt.lua")
-- (pcall: if kawt is missing or broken, Hyprland just skips it instead of failing)
-- It loads this file straight from the kawt folder, so updates to kawt need no copying.
--
-- The launcher sits on SUPER + SPACE (where rofi usually is) and SUPER + R opens it in
-- run mode: comment out your own SUPER + SPACE / SUPER + R lines, otherwise both fire.

-- every bind ends with a "-- comment": the key list (super + /) is read from them
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
    hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd(kawt .. "clipboard")) -- clipboard history
    hl.bind(mod .. " + D", hl.dsp.exec_cmd(kawt .. "toggle dock")) -- pinned apps
    hl.bind(mod .. " + A", hl.dsp.exec_cmd(kawt .. "sidebar")) -- local ai
    hl.bind(mod .. " + W", hl.dsp.exec_cmd(kawt .. "toggle style")) -- wallpaper & themes
    hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(kawt .. "toggleLight")) -- dark <-> light
    hl.bind(mod .. " + N", hl.dsp.exec_cmd(kawt .. "toggle notifs")) -- notification log
    hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(kawt .. "dnd")) -- do not disturb
    hl.bind(mod .. " + I", hl.dsp.exec_cmd(kawt .. "toggle dashboard")) -- the profile, full screen
    hl.bind(mod .. " + L", hl.dsp.exec_cmd(kawt .. "lock")) -- lock screen
    hl.bind(mod .. " + slash", hl.dsp.exec_cmd(kawt .. "toggle keys")) -- this list of keys
    hl.bind(mod .. " + Escape", hl.dsp.exec_cmd(kawt .. "toggle power")) -- shutdown / reboot / suspend menu
    -- screenshots: saved to the folder from the profile's cfg tab, and copied
    hl.bind("Print", hl.dsp.exec_cmd(kawt .. "screenshot region")) -- screenshot of an area
    hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(kawt .. "screenshot region")) -- screenshot of an area
    hl.bind("SHIFT + Print", hl.dsp.exec_cmd(kawt .. "screenshot screen")) -- screenshot of the screen
    hl.bind("ALT + Print", hl.dsp.exec_cmd(kawt .. "screenshot window")) -- screenshot of the window
    -- screen recording: the same key again stops it
    hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(kawt .. "record region")) -- record an area (again: stop)
    hl.bind(mod .. " + ALT + R", hl.dsp.exec_cmd(kawt .. "record screen")) -- record the screen (again: stop)
end)

-- Media keys through kawt (optional): the osd shows at once and kawt doesn't have to poll the
-- brightness. Remove your own XF86 binds first (both would fire), then uncomment:
-- try("media keys", function()
--     hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(kawt .. "volume up"), { locked = true })
--     hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(kawt .. "volume down"), { locked = true })
--     hl.bind("XF86AudioMute", hl.dsp.exec_cmd(kawt .. "volume mute"), { locked = true })
--     hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(kawt .. "mic mute"), { locked = true })
--     hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(kawt .. "brightness up"), { locked = true })
--     hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(kawt .. "brightness down"), { locked = true })
-- end)
-- Locking: kawt locks by itself before sleep (the lid too), on `loginctl lock-session` and after
-- 10 idle minutes (profile -> cfg). No hypridle / hyprlock needed; if you keep them, turn
-- kawt's off there, or two lockers fight.

-- the kawt look: square windows, like the bar. kawt.lua is loaded last, so this wins over
-- the rounding in hyprland.lua; delete this block to keep your own.
-- allow_session_lock_restore: if the kawt lock screen ever crashes, restarting quickshell
-- (from a tty: qs -c kawt-shell -d) brings it back instead of leaving the screen stuck.
-- (two separate calls: if one option doesn't exist in your Hyprland version, the other still applies)
try("square windows", function()
    hl.config({ decoration = { rounding = 0 } })
end)
try("lock restore", function()
    hl.config({ misc = { allow_session_lock_restore = true } })
end)

-- kawt animates its panels itself
try("layer rule", function()
    hl.layer_rule({
        name = "kawt-no-anim",
        match = { namespace = "^kawt-(popover|launcher|style|toasts|sidebar|osd|power|dashboard|keys)$" },
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
