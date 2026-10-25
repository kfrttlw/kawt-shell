#!/bin/sh
# usage: wallpaper.sh <awww|swww> <file> [start | crt | fade | grow | random | none]
# Shows <file> through awww (or swww, its old name), starting its daemon first if it isn't
# running: kawt does that itself (services/Wallpapers.qml), so no config line or autostart is
# needed for it. start: at login, when the daemon may already show it (it keeps the last one):
# then nothing is drawn again, otherwise it comes without a transition.
# The transitions (Settings.wallpaperTransition):
#   crt     drawn in from the top, at 20 frames a second: in steps, like an old screen's beam
#   fade    the new one fades in
#   grow    a circle from the middle
#   random  one of awww's own, a different one each time
#   none    at once
# exit 1: the daemon didn't come up

w=$1
file=$2
start=${3:-}
command -v "$w" > /dev/null || exit 1

if ! "$w" query > /dev/null 2>&1; then
    # in a session of its own: it stays when kawt restarts
    setsid -f "$w-daemon" > /dev/null 2>&1 || exit 1
    i=0
    until "$w" query > /dev/null 2>&1; do
        i=$((i + 1))
        [ $i -gt 50 ] && exit 1 # 5 s
        sleep 0.1
    done
fi

[ -n "$file" ] && [ -f "$file" ] || exit 0
case $start in
    start)
        # "eDP-1: 1920x1080, scale: 1, currently displaying: image: /path/to/it.png"
        "$w" query 2> /dev/null | grep -F -- "$file" > /dev/null && exit 0
        set -- --transition-type none
        ;;
    crt) set -- --transition-type top --transition-fps 20 --transition-duration 0.8 --transition-bezier 0,0,1,1 ;;
    fade) set -- --transition-type fade --transition-duration 1.2 ;;
    grow) set -- --transition-type center --transition-duration 1 ;;
    random) set -- --transition-type random ;;
    none) set -- --transition-type none ;;
    *) set -- ;;
esac
exec "$w" img "$@" -- "$file"
