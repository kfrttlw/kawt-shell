#!/bin/sh
# usage: screenshot.sh <region|window|screen> <dir> [selection color] [shade color] [quiet]
# exit: 0 the path printed, 1 cancelled (esc), 3 "missing: <tools>" printed, 4 a failure said
# Saves a png to <dir>, copies it to the clipboard and sends a notification. Prints the path.
# quiet: only saves and prints the path (kawt's preview asks what to do with it).
# Needs grim, slurp and wl-clipboard. Colors are #rrggbb[aa] (the kawt theme passes its own).
# KAWT_FREEZE=1: the screen stands still while an area is picked (hyprpicker shows the frozen
# picture under the selection; a video or an animation can't move away from it meanwhile).

mode=${1:-region}
dir=${2:-$HOME/Pictures/screenshots}
color=${3:-#ffffffff}
shade=${4:-#00000066}
quiet=${5:-}

# kawt stops a shot that hangs (a new press starts over): what this started goes with it
trap 'pkill -P $$ 2> /dev/null; exit 1' TERM INT

# what's missing is said (exit 3), so kawt can tell you instead of doing nothing
need="grim wl-copy"
[ "$mode" = region ] && need="$need slurp"
[ "$mode" = region ] || need="$need hyprctl"
missing=""
for c in $need; do
    command -v "$c" > /dev/null 2>&1 || missing="$missing $c"
done
if [ -n "$missing" ]; then
    echo "missing:$missing"
    exit 3
fi

mkdir -p "$dir" || { echo "can't write: $dir"; exit 4; }
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
        if [ "${KAWT_FREEZE:-}" = 1 ] && command -v hyprpicker > /dev/null; then
            # -r: the frozen picture on every screen, -z: no zoom lens. Gone again however this ends
            hyprpicker -r -z > /dev/null 2>&1 &
            frozen=$!
            trap 'kill "$frozen" 2> /dev/null' EXIT
            # slurp has to come up above it: started first, hyprpicker would take the click
            # (it picks a color and quits, and the shot is gone). So wait until hyprland has its
            # layer, 1.5 s at most, instead of a fixed guess
            i=0
            until hyprctl layers 2> /dev/null | grep -q 'namespace: hyprpicker' || [ "$i" -ge 30 ]; do
                sleep 0.05
                i=$((i + 1))
            done
            sleep 0.05 # its first frame
        fi
        # esc in slurp cancels: no file, no notification
        geo=$(slurp -d -c "$color" -b "$shade" -w 1) || exit 1
        grim -g "$geo" "$file" || { echo "grim failed"; exit 4; }
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
