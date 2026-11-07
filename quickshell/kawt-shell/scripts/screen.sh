#!/bin/sh
# usage: screen.sh on|off
# Switches the screens' picture off and on (dpms) for services/Idle.qml: only the picture.
# The machine keeps running as it was: wifi, downloads, music, ssh. Any key or the mouse
# brings the picture back (kawt sees the input, and hypr/kawt.lua lets hyprland do it too).
# Hyprland takes its dispatchers as lua with hyprland.lua and in the classic words with
# hyprland.conf; the ways are tried in turn and the one that worked is remembered for the
# session. Without hyprctl: wlopm, if installed. exit 1: no way worked

act=$1
case $act in on | off) ;; *) exit 2 ;; esac
memo=${XDG_RUNTIME_DIR:-/tmp}/kawt-screen-way

try() { # try <dispatcher>: hyprctl answers "ok" when it was done
    [ "$(hyprctl dispatch "$1" 2> /dev/null)" = ok ]
}
way() { # way <n>: the n-th way, for $act
    case $1 in
        1) try "hl.dsp.dpms({ action = \"$act\" })" ;;
        2) try "hl.dsp.dpms(\"$act\")" ;;
        3) try "dpms $act" ;;
        4) command -v wlopm > /dev/null && wlopm --"$act" '*' > /dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# the remembered one first, then the rest
known=$(cat "$memo" 2> /dev/null)
[ -n "$known" ] && way "$known" && exit 0
for n in 1 2 3 4; do
    [ "$n" = "$known" ] && continue
    if way "$n"; then
        printf '%s\n' "$n" > "$memo"
        exit 0
    fi
done
exit 1
