#!/bin/sh
# usage: apply-theme.sh <dir> <name> <content> [<name> <content> ...]
# Writes each <content> to <dir>/<name>; an absolute <name> is written as-is if its directory exists.
# Pseudo names:
#   @pts        content is escape sequences, sent to every terminal we own (recolors them live)
#   @hyprreload reload Hyprland so it picks up the new border colors

dir=$1
shift
mkdir -p "$dir"

while [ $# -ge 2 ]; do
    name=$1
    content=$2
    shift 2
    case $name in
        @pts)
            for p in /dev/pts/[0-9]*; do
                [ -O "$p" ] && [ -w "$p" ] && printf '%s' "$content" > "$p" 2>/dev/null
            done
            ;;
        @hyprreload)
            hyprctl reload > /dev/null 2>&1
            ;;
        /*)
            [ -d "$(dirname "$name")" ] && printf '%s\n' "$content" > "$name"
            ;;
        *)
            printf '%s\n' "$content" > "$dir/$name"
            ;;
    esac
done
