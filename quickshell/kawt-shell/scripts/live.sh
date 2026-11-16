#!/bin/sh
# usage: live.sh poster <video> <out.png> <width> <height>
#        live.sh plain  <video> <out.mkv> <width> <height>
#        live.sh tones  <video> <out.mkv> <width> <height> <lo> <hi> <accent> <gamma> [<key>]
# A live wallpaper (services/LiveWall.qml), made light once and kept in ~/.cache/kawt/live:
#   poster  its first frame as a picture: what's on the screen while it doesn't play
#   plain   the video as it is, cut to the screen's shape, 24 frames a second, silent, two
#           minutes at most, as h264: what any graphics card plays by itself
#   tones   the same in the theme's tones, dotted like the pictures (scripts/dither.sh), at half
#           the screen's size: the player doubles the dots
# Prints the file and, for a video, its length in seconds. A copy that's there already is only
# printed (and kept as the newest: the four newest stay). Made at the lowest priority, written
# aside and renamed when whole, so a half one is never played.
# exit 1: ffmpeg is missing or couldn't read it; 2: a wrong mode
mode=$1 in=$2 out=$3 w=$4 h=$5
command -v ffmpeg > /dev/null || exit 1
[ -f "$in" ] || exit 1

length() {
    [ "$mode" = poster ] || ffprobe -v error -show_entries format=duration -of csv=p=0 "$out" 2> /dev/null
}

if [ -s "$out" ]; then
    touch "$out"
    echo "$out"
    length
    exit 0
fi

mkdir -p "${out%/*}" || exit 1
part="$out.part.${out##*.}"
trap 'rm -f "$part"' EXIT
case $mode in
    poster)
        nice -n 19 ffmpeg -v error -nostdin -y -i "$in" -frames:v 1 \
            -vf "scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h" "$part" || exit 1
        ;;
    plain)
        nice -n 19 ffmpeg -v error -nostdin -y -t 120 -i "$in" \
            -vf "fps=24,scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,setsar=1" \
            -an -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p -g 48 "$part" || exit 1
        ;;
    tones)
        shift 5
        nice -n 19 sh "${0%/*}/dither.sh" "$in" "$part" "$w" "$h" "$@" || exit 1
        ;;
    *)
        exit 2
        ;;
esac
mv -f "$part" "$out" || exit 1
# the four newest copies stay (a theme switched back and forth is quick again)
[ "$mode" = poster ] || (cd "${out%/*}" && ls -t -- *.mkv 2> /dev/null | tail -n +5 | xargs -r rm -f --)
echo "$out"
length
