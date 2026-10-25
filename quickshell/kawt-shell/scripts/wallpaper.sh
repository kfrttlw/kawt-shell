#!/bin/sh
# usage: wallpaper.sh <awww|swww> <file> [start]
# Shows <file> through awww (or swww, its old name), starting its daemon first if it isn't
# running: kawt does that itself (services/Wallpapers.qml), so no config line or autostart is
# needed for it. start: at login, when the daemon may already show it (it keeps the last one):
# then nothing is drawn again, otherwise it comes without a transition.
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
if [ "$start" = start ]; then
    # "eDP-1: 1920x1080, scale: 1, currently displaying: image: /path/to/it.png"
    "$w" query 2> /dev/null | grep -F -- "$file" > /dev/null && exit 0
    exec "$w" img --transition-type none -- "$file"
fi
exec "$w" img -- "$file"
