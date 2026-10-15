# kawt: Hyprland from the text console (tty) a machine without a login screen boots to.
# install.sh asks how you want it and adds one line for that:
#   by itself   ~/.zprofile (or ~/.bash_profile) reads this file at every login: on tty1
#               Hyprland starts right away. The other consoles (ctrl+alt+F2...) stay plain
#               text logins, a way back in if Hyprland ever doesn't start
#   a command   ~/.zshrc (or ~/.bashrc) gets `start`, which reads it with "now": Hyprland
#               starts when you type it
# Through uwsm if it's installed (Hyprland as a systemd session, like `uwsm start
# hyprland.desktop`; uwsm itself says no when one is already running), otherwise Hyprland's
# own launcher start-hyprland (it restarts Hyprland in a safe mode if it crashes), or
# Hyprland itself on older versions.
if [[ ${1:-} == now || ( -z ${WAYLAND_DISPLAY:-} && ${XDG_VTNR:-} == 1 ) ]]; then
    if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
        echo "hyprland is already running"
    elif command -v uwsm > /dev/null; then
        uwsm check may-start && exec uwsm start hyprland.desktop
        [[ ${1:-} == now ]] && echo "uwsm won't start it here: already running, or not on tty1?"
    elif command -v start-hyprland > /dev/null; then
        exec start-hyprland
    elif command -v Hyprland > /dev/null; then
        exec Hyprland
    elif [[ ${1:-} == now ]]; then
        echo "hyprland isn't installed"
    fi
fi
