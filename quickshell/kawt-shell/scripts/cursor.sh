#!/bin/sh
# usage: cursor.sh <cursors dir> <theme> <size> [<was>]
# kawt's cursor on (services/Cursor.qml): <theme> is kawt-stripes or kawt-terminal, drawn by
# tools/cursors.py into <cursors dir>. With no <theme>, the cursor from before kawt's back: <was>,
# "name size", which kawt keeps; the first time its own goes on, this prints the one there was as
# "was=name size" for it.
# Hyprland draws the cursor over every window (hyprctl setcursor; a theme hyprcursor doesn't know
# it takes as XCursor) and tells GTK itself (gsettings, cursor:sync_gsettings_theme).
dir=$1 theme=$2 size=$3 was=${4:-}
icons=${XDG_DATA_HOME:-$HOME/.local/share}/icons
case $size in '' | *[!0-9]*) size=24 ;; esac

if [ -z "$theme" ]; then
    # never put on, or given back already: nothing to do
    [ -n "$was" ] || exit 0
    n=${was##* }
    case $n in '' | *[!0-9]*) n=24 ;; esac
    exec hyprctl setcursor "${was% *}" "$n" > /dev/null
fi

[ -d "$dir/$theme/cursors" ] || exit 1
# kawt's themes where every program looks for cursors: a link each, into kawt. A folder of yours
# with that name is left alone; a link of kawt's that points elsewhere (an old clone) is set right
mkdir -p "$icons" || exit 1
for t in "$dir"/kawt-*; do
    dst=$icons/${t##*/}
    if [ -L "$dst" ]; then
        [ "$(readlink -- "$dst")" = "$t" ] || ln -sfn -- "$t" "$dst"
    elif [ ! -e "$dst" ]; then
        ln -s -- "$t" "$dst"
    fi
done

# the one there was, to give back later: gsettings has what hyprland last said, or the
# environment; kawt's own (left from an earlier time) or nothing: the system's default
if [ -z "$was" ]; then
    name=$(gsettings get org.gnome.desktop.interface cursor-theme 2> /dev/null | tr -d "'")
    n=$(gsettings get org.gnome.desktop.interface cursor-size 2> /dev/null)
    case $name in kawt-* | '') name=${XCURSOR_THEME:-} ;; esac
    case $name in kawt-* | '' | *' '*) name=default ;; esac
    case $n in '' | *[!0-9]*) n=${XCURSOR_SIZE:-24} ;; esac
    case $n in '' | *[!0-9]*) n=24 ;; esac
    echo "was=$name $n"
fi
exec hyprctl setcursor "$theme" "$size" > /dev/null
