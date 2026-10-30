#!/bin/sh
# usage: record.sh <region|screen> <file> [selection color] [shade color] [sound]
# Records with wf-recorder until it gets SIGINT (kawt sends it to stop); the video is
# finalized properly either way.
# sound: off | mic (the default microphone) | system (what you hear: the default output's
#        monitor) | both (the two mixed: a temporary sink with two loopbacks into it, made with
#        pactl and taken away again afterwards). "1" / "0" (older kawt) are mic / off.
# exit 3: the region selection was cancelled (esc in slurp, or kawt stopped it meanwhile)

mode=${1:-region}
file=$2
color=${3:-#ffffffff}
shade=${4:-#00000066}
sound=${5:-off}
case $sound in 1) sound=mic ;; 0 | "") sound=off ;; esac

mkdir -p "$(dirname "$file")" || exit 1

# stopped before the recording began (the key again while the area is picked): slurp goes too,
# instead of staying on the screen, and it's a cancel, not a failed recording. Once wf-recorder
# runs, the stop goes to it instead (below)
geofile=""
trap 'pkill -P $$ 2> /dev/null; rm -f "$geofile"; exit 3' INT TERM

case $mode in
    region)
        # in the background and waited for: the stop is heard at once (waited for in front, it
        # was heard only once slurp was done, so slurp stayed until a click)
        geofile=$(mktemp)
        slurp -d -c "$color" -b "$shade" -w 1 > "$geofile" &
        wait $! || { rm -f "$geofile"; exit 3; }
        geo=$(cat "$geofile")
        rm -f "$geofile"
        [ -n "$geo" ] || exit 3
        set -- -g "$geo"
        ;;
    screen)
        out=$(hyprctl monitors | awk '/^Monitor/ {m = $2} /focused: yes/ {print m; exit}')
        set --
        [ -n "$out" ] && set -- -o "$out"
        ;;
    *)
        echo "unknown mode: $mode" >&2
        exit 2
        ;;
esac

# the default output, by its pulse name (what wf-recorder's --audio takes; its monitor is
# "<name>.monitor"): pactl, or wireplumber's wpctl without it
sink() {
    pactl get-default-sink 2> /dev/null && return
    wpctl inspect @DEFAULT_AUDIO_SINK@ 2> /dev/null | sed -n 's/.*node\.name = "\(.*\)"/\1/p' | head -n 1
}

modules=""
case $sound in
    mic) set -- "$@" --audio ;;
    system)
        s=$(sink)
        [ -n "$s" ] && set -- "$@" --audio="$s.monitor"
        ;;
    both)
        s=$(sink)
        if [ -n "$s" ] && command -v pactl > /dev/null &&
            m1=$(pactl load-module module-null-sink sink_name=kawt_rec sink_properties=device.description=kawt-recording) &&
            m2=$(pactl load-module module-loopback source="$s.monitor" sink=kawt_rec latency_msec=30) &&
            m3=$(pactl load-module module-loopback source=@DEFAULT_SOURCE@ sink=kawt_rec latency_msec=30); then
            modules="$m3 $m2 $m1"
            set -- "$@" --audio=kawt_rec.monitor
        else
            # no pactl: what you hear is the more common wish
            for m in ${m2:-} ${m1:-}; do pactl unload-module "$m" 2> /dev/null; done
            [ -n "$s" ] && set -- "$@" --audio="$s.monitor"
        fi
        ;;
esac

if [ -z "$modules" ]; then
    # exec: the signal reaches wf-recorder itself
    exec wf-recorder "$@" -f "$file"
fi

# with the mix to take away afterwards: wf-recorder runs as a child, the stop signal is passed on.
# A child sent off with & has SIGINT ignored in a script; env gives it back its default
trap 'kill -INT "$rec" 2> /dev/null' INT TERM
if env --default-signal=INT true 2> /dev/null; then
    env --default-signal=INT wf-recorder "$@" -f "$file" &
else
    wf-recorder "$@" -f "$file" &
fi
rec=$!
wait "$rec"
code=$?
# the signal ends that wait early: wait on until wf-recorder has written the file
while kill -0 "$rec" 2> /dev/null; do
    wait "$rec"
    code=$?
done
for m in $modules; do pactl unload-module "$m" 2> /dev/null; done
exit $code
