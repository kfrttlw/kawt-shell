#!/bin/sh
# usage: screenshot.sh <region|window|screen> <dir> [selection color] [shade color] [quiet]
# Saves a png to <dir>, copies it to the clipboard and sends a notification. Prints the path.
# quiet: only saves and prints the path (kawt's preview asks what to do with it).
# Needs grim, slurp and wl-clipboard. Colors are #rrggbb[aa] (the kawt theme passes its own).

mode=${1:-region}
dir=${2:-$HOME/Pictures/screenshots}
color=${3:-#ffffffff}
shade=${4:-#00000066}
quiet=${5:-}

mkdir -p "$dir" || exit 1
# two shots in the same second: the second one gets -2 (-3...), nothing is written over
name=$(date +%Y-%m-%d_%H-%M-%S)
file="$dir/$name.png"
n=2
while [ -e "$file" ]; do
    file="$dir/$name-$n.png"
    n=$((n + 1))
done

case $mode in
    region)
        # esc in slurp cancels: no file, no notification
        geo=$(slurp -d -c "$color" -b "$shade" -w 1) || exit 1
        grim -g "$geo" "$file" || exit 1
        ;;
    window)
        # hyprctl activewindow:  "at: 10,40"  "size: 800,600"
        geo=$(hyprctl activewindow | awk '/^\tat:/ {split($2, a, ",")} /^\tsize:/ {split($2, s, ",")} END {if (s[1]) printf "%s,%s %sx%s", a[1], a[2], s[1], s[2]}')
        [ -n "$geo" ] || exit 1
        grim -g "$geo" "$file" || exit 1
        ;;
    screen)
        # the monitor with the focus: "Monitor eDP-1 (ID 0):" ... "focused: yes"
        out=$(hyprctl monitors | awk '/^Monitor/ {m = $2} /focused: yes/ {print m; exit}')
        if [ -n "$out" ]; then grim -o "$out" "$file"; else grim "$file"; fi || exit 1
        ;;
    *)
        echo "unknown mode: $mode (region|window|screen)" >&2
        exit 2
        ;;
esac

if [ "$quiet" = quiet ]; then
    echo "$file"
    exit 0
fi
wl-copy --type image/png < "$file"
notify-send -a screenshot -i "$file" "screenshot saved" "${file#"$HOME"/}  ·  copied to clipboard"
echo "$file"
