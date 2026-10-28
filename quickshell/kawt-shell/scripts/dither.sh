#!/bin/sh
# usage: dither.sh <picture> <out.png> <width> <height> <lo> <hi> <accent> <gamma>
# A wallpaper the way an old screen would show it: the picture in the theme's few tones, mixed
# by ordered (bayer) dithering, every dot two pixels big. Its bright reds (a sunset, a lamp) stay:
# lit dots of the accent among the rest. ffmpeg only (kawt needs it anyway).
#   width height  the screen's half: the dots are doubled to it
#   lo hi         #rrggbb: what black and white become; the five tones lie between them
#                 (dark themes: the background up to a dim ink; light ones: ink up to the paper)
#   gamma         >1 darker, <1 lighter (how much of the picture sits in the shadows)
# exit 1: ffmpeg is missing or couldn't read the picture
in=$1 out=$2 w=$3 h=$4 lo=$5 hi=$6 accent=$7 gamma=${8:-1}
command -v ffmpeg > /dev/null || exit 1
[ -f "$in" ] || exit 1

# #rrggbb -> "r g b"
rgb() {
    printf '%d %d %d' "0x$(echo "$1" | cut -c2-3)" "0x$(echo "$1" | cut -c4-5)" "0x$(echo "$1" | cut -c6-7)"
}
set -- $(rgb "$lo") $(rgb "$hi") $(rgb "$accent")
r0=$1 g0=$2 b0=$3 r1=$4 g1=$5 b1=$6 ra=$7 ga=$8 ba=$9

# the palette: 16x16 pixels as ffmpeg's paletteuse wants them, the five tones over and over
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
{
    printf 'P6\n16 16\n255\n'
    i=0
    while [ $i -lt 256 ]; do
        k=$((i % 5))
        r=$((r0 + (r1 - r0) * k / 4)) g=$((g0 + (g1 - g0) * k / 4)) b=$((b0 + (b1 - b0) * k / 4))
        printf "\\$(printf %o "$r")\\$(printf %o "$g")\\$(printf %o "$b")"
        i=$((i + 1))
    done
} > "$tmp/palette.ppm"

# what black..white becomes, along the line from lo to hi
lut() { echo "$1+($2-$1)*pow(val/255\\,$gamma)"; }
# the 4x4 bayer threshold of a pixel, 0..255, from the 2x2 one ((0 2) (3 1)) twice over
b2() { echo "(2*($1+$2-2*$1*$2)+$2)"; }
bayer="(4*$(b2 'mod(X\,2)' 'mod(Y\,2)')+$(b2 'mod(floor(X/2)\,2)' 'mod(floor(Y/2)\,2)')+0.5)*16"

# the picture cut to the screen's shape; in grey, laid on the line from lo to hi, dithered into
# the five tones. Its reds: a mask, against the same bayer pattern, so at most every other dot
# in a red patch is the accent (a lit dot pattern, not a flat shape); every dot then doubled
ffmpeg -v error -nostdin -y -i "$in" -i "$tmp/palette.ppm" -filter_complex "\
[0:v]scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,setsar=1,format=rgb24,split[a][b];\
[a]format=gray,format=rgb24,lutrgb=r='$(lut $r0 $r1)':g='$(lut $g0 $g1)':b='$(lut $b0 $b1)'[tone];\
[tone][1:v]paletteuse=dither=bayer:bayer_scale=2[dots];\
[b]colorkey=0xe03018:0.14:0.07,format=rgba,alphaextract,negate[red];\
color=c=black:s=${w}x$h,format=gray,geq=lum='$bayer'[threshold];\
[red][threshold]blend=all_expr='if(gt(A*0.55\,B)\,255\,0)':shortest=1[hit];\
color=c=0x$(echo "$accent" | cut -c2-7):s=${w}x$h,format=rgba[plane];\
[plane][hit]alphamerge[lit];\
[dots][lit]overlay=format=rgb:shortest=1,scale=iw*2:ih*2:flags=neighbor" -frames:v 1 "$out" || exit 1
