#!/bin/sh
# usage: screenshot.sh <region|window|screen> <dir> [selection color] [shade color] [quiet]
# exit: 0 the path printed, 1 cancelled (esc), 3 "missing: <tools>" printed, 4 a failure said
# (what slurp, grim or hyprctl said is printed too: kawt shows it instead of doing nothing)
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
geofile=""
err=""
trap 'pkill -P $$ 2> /dev/null; rm -f "$geofile" "$err"; exit 1' TERM INT

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
            # never came up: no freezing this time. Coming up later it would lie over slurp
            # and take the click
            if [ "$i" -ge 30 ]; then
                kill "$frozen" 2> /dev/null
            else
                sleep 0.05 # its first frame
            fi
        fi
        # esc in slurp cancels: no file, no notification. Anything else it says is said.
        # < /dev/null: slurp whose stdin isn't a terminal first reads boxes to offer from it,
        # until it ends, before it even shows. kawt's stdin never ends (quickshell closes it
        # before the start, and that never reaches the child), so slurp waited there for good,
        # out of sight: print and super+shift+s did nothing. In a terminal it worked.
        # In the background and waited for: a stop from kawt is heard at once
        geofile=$(mktemp)
        err=$(mktemp)
        slurp -d -c "$color" -b "$shade" -w 1 < /dev/null > "$geofile" 2> "$err" &
        wait $!
        st=$?
        geo=$(cat "$geofile")
        if [ "$st" -ne 0 ] || [ -z "$geo" ]; then
            if [ "$st" -eq 0 ] || grep -qi cancel "$err"; then
                rm -f "$geofile" "$err"
                exit 1
            fi
            echo "slurp: $(tr '\n' ' ' < "$err" | cut -c1-200)"
            rm -f "$geofile" "$err"
            exit 4
        fi
        rm -f "$geofile" "$err"
        out=$(grim -g "$geo" "$file" 2>&1) || { echo "grim: ${out:-failed}"; exit 4; }
        ;;
    window)
        # hyprctl activewindow:  "at: 10,40"  "size: 800,600"
        geo=$(hyprctl activewindow | awk '/^\tat:/ {split($2, a, ",")} /^\tsize:/ {split($2, s, ",")} END {if (s[1]) printf "%s,%s %sx%s", a[1], a[2], s[1], s[2]}')
        [ -n "$geo" ] || { echo "no window has the focus"; exit 4; }
        out=$(grim -g "$geo" "$file" 2>&1) || { echo "grim: ${out:-failed}"; exit 4; }
        ;;
    screen)
        # the monitor with the focus: "Monitor eDP-1 (ID 0):" ... "focused: yes"
        out=$(hyprctl monitors | awk '/^Monitor/ {m = $2} /focused: yes/ {print m; exit}')
        if [ -n "$out" ]; then out=$(grim -o "$out" "$file" 2>&1); else out=$(grim "$file" 2>&1); fi || { echo "grim: ${out:-failed}"; exit 4; }
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
