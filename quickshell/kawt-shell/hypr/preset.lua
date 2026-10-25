-- kawt's standard Hyprland config (0.55+, Lua): the kawt preset.
--
-- Loaded from ~/.config/hypr/hyprland.lua, straight from the kawt folder: `git pull` updates
-- it. Don't edit it here (an update would take your change back): everything of your own goes
-- to ~/.config/hypr/user.lua, loaded after this and after kawt.lua, so it wins:
--   settings   just set them again there (hl.config, hl.animation, hl.env...: the last one counts)
--   keys       a key bound twice does both, so free it first: preset.unbind("SUPER + V"), then bind yours
--   programs   preset.terminal = "foot" (also preset.files, preset.browser): the keys below read these
-- Every part runs in its own pcall, like kawt.lua: if something here doesn't fit your Hyprland
-- version, only that part is skipped, the rest still works.
-- Binds with a "-- comment" at the end show up in kawt's key list (super + /).

preset = {
    terminal = "kitty",
    files    = "thunar",  -- file manager: or dolphin, nautilus, nemo...
    browser  = "firefox",
    binds    = {},        -- "SUPER+V" -> the bind, for preset.unbind
}

local kawt = "qs -c kawt-shell ipc call kawt "
local mainMod = "SUPER"

local function try(what, fn)
    local ok, err = pcall(fn)
    if not ok then
        print("preset.lua: " .. what .. " skipped: " .. tostring(err))
    end
end

-- "SUPER + SHIFT + s" -> "SUPER+SHIFT+S"
local function norm(keys)
    return (keys:upper():gsub("%s+", ""))
end

-- hl.bind, remembered by its keys
local function bind(keys, action, opts)
    local b = hl.bind(keys, action, opts)
    preset.binds[norm(keys)] = b
    return b
end

-- free a key of this file for one of your own (in user.lua)
function preset.unbind(keys)
    local b = preset.binds[norm(keys)]
    if b ~= nil then
        b:set_enabled(false)
    end
end

-- a key that starts one of the programs above: read when pressed, so user.lua can change them
local function run(which)
    return function()
        hl.dispatch(hl.dsp.exec_cmd(preset[which]))
    end
end


------------------
---- MONITORS ----
------------------

-- any monitor: its preferred mode. Your own go to user.lua (names and modes: hyprctl monitors all)
try("monitors", function()
    hl.monitor({
        output   = "",
        mode     = "preferred",
        position = "auto",
        scale    = "auto",
    })
end)


-------------------
---- AUTOSTART ----
-------------------

-- kawt itself and the password window start from kawt.lua; the wallpaper daemon (awww or
-- swww) kawt starts itself, with the last wallpaper (services/Wallpapers.qml). Your own
-- programs: hl.on("hyprland.start", ...) in user.lua.


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

try("environment", function()
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_SIZE", "24")
    hl.env("QT_QPA_PLATFORM", "wayland;xcb")              -- Qt apps native on Wayland
    hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")    -- no extra title bars on Qt apps
    hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")        -- Discord / VS Code on Wayland, not blurry
    hl.env("GDK_BACKEND", "wayland,x11,*")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

try("look", function()
    hl.config({
        general = {
            gaps_in     = 5,
            gaps_out    = 14,
            border_size = 2,
            -- kawt.lua sets these from the current theme; only a fallback
            col = {
                active_border   = "rgba(33ff99ee)",
                inactive_border = "rgba(595959aa)",
            },
            resize_on_border = true,
            allow_tearing    = false,
            layout           = "dwindle",
        },

        decoration = {
            rounding = 0, -- square windows, like the bar

            active_opacity   = 1.0,
            inactive_opacity = 1.0,

            shadow = {
                enabled      = true,
                range        = 6,
                render_power = 3,
                color        = 0xee1a1a1a, -- kawt recolors it for the theme
            },

            blur = {
                enabled  = true,
                size     = 3,
                passes   = 2,
                vibrancy = 0.17,
                new_optimizations = true,
            },
        },

        animations = { enabled = true },
    })
end)


--------------------
---- ANIMATIONS ----
--------------------
-- an old terminal / CRT: no springs, no bouncing. Quick and dry, windows open out of a line
-- (gnomed), like a picture tube switching on. speed: 1 = 100 ms.

try("animations", function()
    hl.curve("kawtOut", { type = "bezier", points = { {0.16, 1},  {0.30, 1}  } }) -- sharp start, soft stop
    hl.curve("kawtIn",  { type = "bezier", points = { {0.70, 0},  {0.84, 0}  } }) -- for closing
    hl.curve("kawtLin", { type = "bezier", points = { {0, 0},     {1, 1}     } })

    hl.animation({ leaf = "global",           enabled = true,  speed = 3,   bezier = "kawtOut" })
    hl.animation({ leaf = "windowsIn",        enabled = true,  speed = 2.6, bezier = "kawtOut", style = "gnomed" })
    hl.animation({ leaf = "windowsOut",       enabled = true,  speed = 1.6, bezier = "kawtIn",  style = "gnomed" })
    hl.animation({ leaf = "windowsMove",      enabled = true,  speed = 2.4, bezier = "kawtOut" })
    hl.animation({ leaf = "fadeIn",           enabled = true,  speed = 1.8, bezier = "kawtLin" })
    hl.animation({ leaf = "fadeOut",          enabled = true,  speed = 1.4, bezier = "kawtLin" })
    hl.animation({ leaf = "fadeSwitch",       enabled = true,  speed = 1.5, bezier = "kawtLin" })
    hl.animation({ leaf = "fadeDim",          enabled = true,  speed = 1.5, bezier = "kawtLin" })
    hl.animation({ leaf = "border",           enabled = true,  speed = 1.2, bezier = "kawtLin" })
    hl.animation({ leaf = "borderangle",      enabled = false })                                   -- one-color border, nothing to turn
    hl.animation({ leaf = "layers",           enabled = true,  speed = 2,   bezier = "kawtOut", style = "fade" }) -- kawt animates its own panels
    hl.animation({ leaf = "workspaces",       enabled = true,  speed = 2.4, bezier = "kawtOut", style = "slidefade 8%" })
    hl.animation({ leaf = "specialWorkspace", enabled = true,  speed = 2.4, bezier = "kawtOut", style = "slidefadevert 10%" })
    hl.animation({ leaf = "zoomFactor",       enabled = true,  speed = 3,   bezier = "kawtOut" })
end)


-----------------
---- LAYOUTS ----
-----------------

try("layouts", function()
    hl.config({
        dwindle   = { preserve_split = true },
        master    = { new_status = "master" },
        scrolling = { fullscreen_on_one_column = true },
    })
end)


----------------
----  MISC  ----
----------------

try("misc", function()
    hl.config({
        misc = {
            force_default_wallpaper = 0,    -- no anime mascot flashing up before the wallpaper
            disable_hyprland_logo   = true,
            focus_on_activate       = true, -- a link clicked in a messenger brings the browser up
        },
        ecosystem = {
            no_update_news   = true,
            no_donation_nag  = true,
        },
    })
end)


---------------
---- INPUT ----
---------------

-- keyboard layouts and mouse speed: in user.lua
try("input", function()
    hl.config({
        input = {
            kb_layout  = "us",
            follow_mouse = 1,
            touchpad = {
                natural_scroll       = false,
                disable_while_typing = true,
                tap_to_click         = true,
            },
        },
    })
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
end)


---------------------
---- KEYBINDINGS ----
---------------------
-- SUPER + SPACE / R / SHIFT + S / L and the rest of kawt's keys are in kawt.lua, not here.

try("keys", function()
    bind(mainMod .. " + Q", run("terminal")) -- terminal
    bind(mainMod .. " + C", hl.dsp.window.close()) -- close the window
    -- leaving Hyprland: on a hard combination, so it isn't pressed by accident
    bind(mainMod .. " + CTRL + SHIFT + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")) -- leave hyprland
    bind(mainMod .. " + E", run("files")) -- file manager
    bind(mainMod .. " + B", run("browser")) -- browser
    bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- pseudo-tile
    bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- split: side by side <-> stacked
    bind(mainMod .. " + F", hl.dsp.window.fullscreen()) -- fullscreen

    -- floating: the window comes out at 900x600 in the middle, not stretched over the screen
    bind(mainMod .. " + V", function() -- floating <-> tiled (900x600, centered)
        hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
        local w = hl.get_active_window()
        if w ~= nil and w.floating then
            hl.dispatch(hl.dsp.window.resize({ x = 900, y = 600, relative = false }))
            hl.dispatch(hl.dsp.window.center())
        end
    end)

    -- keys: super+arrows | focus left / right / up / down
    -- keys: super+shift+arrows | swap the window with its neighbour
    -- keys: super+ctrl+arrows | resize (hold to keep going)
    local step = 40
    for _, d in ipairs({ "left", "right", "up", "down" }) do
        local x = (d == "left" and -step) or (d == "right" and step) or 0
        local y = (d == "up" and -step) or (d == "down" and step) or 0
        bind(mainMod .. " + " .. d,              hl.dsp.focus({ direction = d }))
        bind(mainMod .. " + SHIFT + " .. d,      hl.dsp.window.move({ direction = d }))
        bind(mainMod .. " + CTRL + " .. d,       hl.dsp.window.resize({ x = x, y = y, relative = true }), { repeating = true })
    end

    -- keys: super+1..0 | workspace 1-10 (with shift: move the window there)
    for i = 1, 10 do
        local key = i % 10
        bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
        bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
    end

    -- scratchpad (SUPER + SHIFT + S is kawt's screenshot, so it moves to SUPER + ALT + S)
    bind(mainMod .. " + S",       hl.dsp.workspace.toggle_special("magic")) -- scratchpad: show / hide
    bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" })) -- the window to the scratchpad

    -- keys: super+wheel | next / previous workspace
    bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

    -- keys: super+drag | move the window (right button: resize)
    bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- volume / brightness through kawt: its osd shows at once
    bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(kawt .. "volume up"),       { locked = true, repeating = true })
    bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(kawt .. "volume down"),     { locked = true, repeating = true })
    bind("XF86AudioMute",         hl.dsp.exec_cmd(kawt .. "volume mute"),     { locked = true })
    bind("XF86AudioMicMute",      hl.dsp.exec_cmd(kawt .. "mic mute"),        { locked = true })
    bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(kawt .. "brightness up"),   { locked = true, repeating = true })
    bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(kawt .. "brightness down"), { locked = true, repeating = true })

    -- play / pause / next go to the player kawt shows (the one picked in its player panel, or
    -- the last one started); playerctl if kawt isn't running
    bind("XF86AudioNext",  hl.dsp.exec_cmd(kawt .. "media next || playerctl next"),         { locked = true })
    bind("XF86AudioPause", hl.dsp.exec_cmd(kawt .. "media toggle || playerctl play-pause"), { locked = true })
    bind("XF86AudioPlay",  hl.dsp.exec_cmd(kawt .. "media toggle || playerctl play-pause"), { locked = true })
    bind("XF86AudioPrev",  hl.dsp.exec_cmd(kawt .. "media prev || playerctl previous"),     { locked = true })
end)

-- WINDOW MODE: SUPER + Z switches it on, Esc / Enter off. Inside, without modifiers:
--   arrows         size
--   SHIFT+arrows   swap / move
--   F              floating <-> tiled
--   C              to the middle
--   P              pin above everything
-- While it's on, these keys don't reach the apps.
try("window mode", function()
    local step = 40
    local mode_binds = {}
    -- -e: only a toast, never in kawt's log. The tag makes each one replace the last: the help
    -- stays up while the mode is on (-t 0), "off" takes its place and goes after 1.5 s
    local function notify(text, ms)
        hl.dispatch(hl.dsp.exec_cmd("notify-send -e -t " .. ms .. " -h string:x-canonical-private-synchronous:wmode '[window]' '" .. text .. "'"))
    end
    local function window_mode(on)
        for _, b in ipairs(mode_binds) do b:set_enabled(on) end
        if on then
            notify("arrows: size · shift+arrows: move · f float · c center · p pin · esc", 0)
        else
            notify("off", 1500)
        end
    end
    local function mode_bind(key, action, opts)
        local b = hl.bind(key, action, opts)
        b:set_enabled(false)
        table.insert(mode_binds, b)
    end

    mode_bind("left",  hl.dsp.window.resize({ x = -step, y = 0,     relative = true }), { repeating = true })
    mode_bind("right", hl.dsp.window.resize({ x =  step, y = 0,     relative = true }), { repeating = true })
    mode_bind("up",    hl.dsp.window.resize({ x = 0,     y = -step, relative = true }), { repeating = true })
    mode_bind("down",  hl.dsp.window.resize({ x = 0,     y =  step, relative = true }), { repeating = true })
    mode_bind("SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
    mode_bind("SHIFT + right", hl.dsp.window.move({ direction = "right" }))
    mode_bind("SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
    mode_bind("SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
    mode_bind("F", hl.dsp.window.float({ action = "toggle" }))
    mode_bind("C", hl.dsp.window.center())
    mode_bind("P", hl.dsp.window.pin())
    mode_bind("Escape", function() window_mode(false) end)
    mode_bind("Return", function() window_mode(false) end)

    bind(mainMod .. " + Z", function() window_mode(true) end) -- window mode: arrows size, shift+arrows move, f c p, esc
end)


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Small tools and settings windows float FROM THE START, centered, WITHOUT a size: the window
-- gets the size the app asks for (a small one stays small, nothing is stretched).
-- A window's class: open it and run  hyprctl activewindow  (the "class" line)
try("window rules", function()
    local float_classes = {
        "^(org.pulseaudio.pavucontrol|pavucontrol)$",
        "^(nm-connection-editor)$",
        "^(blueman-manager)$",
        "^(nwg-look)$",
        "^(qt5ct|qt6ct)$",
        "^(org.gnome.FileRoller|file-roller)$",
        "^(xdg-desktop-portal-gtk)$",   -- "open file" from the browser
        "^(hyprpolkitagent)$",          -- the password window
        "^(qalculate-gtk)$",
    }
    for _, c in ipairs(float_classes) do
        hl.window_rule({ match = { class = c }, float = true, center = true })
    end

    -- dialogs, by title (their class is their parent's)
    local float_titles = {
        "^(Open File.*)$", "^(Open Folder.*)$", "^(Save As.*)$", "^(Save File.*)$",
        "^(Select .*)$",   "^(Choose .*)$",     "^(File Operation Progress)$",
        "^(Library)$",     "^(Friends List)$",                      -- firefox downloads, steam friends
    }
    for _, t in ipairs(float_titles) do
        hl.window_rule({ match = { title = t }, float = true, center = true })
    end

    -- firefox picture-in-picture: small, above everything
    hl.window_rule({
        match = { title = "^(Picture-in-Picture)$" },
        float = true, pin = true, size = "640 360", keep_aspect_ratio = true,
    })

    -- apps asking to be maximized are ignored: windows stay where the layout puts them
    hl.window_rule({
        name  = "suppress-maximize-events",
        match = { class = ".*" },
        suppress_event = "maximize",
    })

    -- dragging in XWayland apps
    hl.window_rule({
        name  = "fix-xwayland-drags",
        match = {
            class = "^$", title = "^$",
            xwayland = true, float = true, fullscreen = false, pin = false,
        },
        no_focus = true,
    })
end)
