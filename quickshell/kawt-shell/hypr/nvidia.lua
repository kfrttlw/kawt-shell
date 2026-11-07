-- NVIDIA for Hyprland 0.55+ (Lua): only on a machine that draws with an nvidia card alone. A
-- laptop with intel / amd graphics next to it (hybrid) doesn't need it: the other gpu draws there.
--
-- install: the installer adds this line to ~/.config/hypr/hyprland.lua when you say yes to it
--   pcall(dofile, os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/nvidia.lua") -- kawt: nvidia
-- (delete that line and this file is out of the game; --uninstall does it too)
-- The driver itself (nvidia-open-dkms) already turns on what Wayland needs (modeset, fbdev).

hl.env("LIBVA_DRIVER_NAME", "nvidia")         -- videos decoded on the gpu (libva-nvidia-driver): firefox, mpv
hl.env("NVD_BACKEND", "direct")               -- the way libva-nvidia-driver works with recent drivers
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia") -- OpenGL through nvidia's own library (screen sharing in discord / zoom broken: remove this line)
