#!/bin/sh
# usage: record.sh <region|screen> <file> [selection color] [shade color] [audio: 0|1]
# Records with wf-recorder until it gets SIGINT (kawt sends it to stop). exec, so the
# signal reaches wf-recorder directly and the video is finalized properly.
# exit 3: the region selection was cancelled (esc in slurp)

mode=${1:-region}
file=$2
color=${3:-#ffffffff}
shade=${4:-#00000066}
audio=${5:-0}

mkdir -p "$(dirname "$file")" || exit 1
set --
[ "$audio" = 1 ] && set -- --audio

case $mode in
    region)
        geo=$(slurp -d -c "$color" -b "$shade" -w 1) || exit 3
        exec wf-recorder "$@" -g "$geo" -f "$file"
        ;;
    screen)
        out=$(hyprctl monitors | awk '/^Monitor/ {m = $2} /focused: yes/ {print m; exit}')
        if [ -n "$out" ]; then exec wf-recorder "$@" -o "$out" -f "$file"; fi
        exec wf-recorder "$@" -f "$file"
        ;;
esac
echo "unknown mode: $mode" >&2
exit 2
