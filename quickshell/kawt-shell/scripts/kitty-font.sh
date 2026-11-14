#!/bin/sh
# usage: kitty-font.sh <font> <size>|auto [<scale>]
# kitty's font, from settings -> look -> terminal (services/KittyFont.qml) and ./install.sh:
#   <font>   term      kawt Term: Terminus, the linux console's, with russian д и й в
#                      (fonts/, tools/termfont.py)                             <size> in pixels
#            plex      IBM Plex Mono, smooth: kitty.conf's own                 <size> in points
#            vga       kawt VGA, the IBM PC's text mode (fonts/, tools/vgafont.py)   <size> in pixels
#            bigblue   Big Blue Terminal, DOS                                  <size> in pixels
#            3270      IBM 3270, the mainframe terminal's, smooth              <size> in points
#   auto     the size nearest 16 of hyprland's pixels (Terminus' own; the letters as tall as
#            plex's at 11 pt, kitty's usual size), at this scale; the
#            file says so, and kawt picks it again when the scale changes
#   <scale>  the screen's, as hyprland has it; not given: the biggest monitor's (hyprctl), or 1
# A pixel font is sharp only when each of its pixels is one of the screen's: <size> is in the
# screen's own pixels (16, 32... for vga), and the points kitty wants are worked out from the
# scale, the way kitty does (96 dpi times the scale, cut to a whole number; points in 64ths).
# The file is kawt's (~/.config/kitty/kawt-font.conf, read after kitty.conf); its first line says
# what was picked, for the settings to show. Changed, every kitty reads its config again (USR1).
# Exit 3: kitty.conf isn't kawt's (the file would be read by nothing); 4: the font isn't
# installed, "missing <package>" said.
font=$1 size=$2 scale=${3:-}
[ "$font" = terminus ] && font=term # the package's Terminus, picked before kawt had its own
conf=${XDG_CONFIG_HOME:-$HOME/.config}/kitty
file=$conf/kawt-font.conf

grep -qs 'globinclude kawt-\*\.conf' "$conf/kitty.conf" || exit 3

case $font in
    # sizes: the ones it's sharp at (a pixel font: whole times its pixel); usual for a smooth one
    term) family="kawt Term" unit=px pkg="" sizes="12 14 16 18 20 22 24 28 32" ;;
    plex) family="BlexMono Nerd Font Mono" unit=pt pkg=ttf-ibmplex-mono-nerd sizes=11 ;;
    vga) family="kawt VGA" unit=px pkg="" sizes="16 32 48 64 80" ;;
    bigblue) family="BigBlueTermPlus Nerd Font Mono" unit=px pkg=ttf-bigblueterminal-nerd sizes="12 24 36 48 60" ;;
    3270) family="3270 Nerd Font Mono" unit=pt pkg=ttf-3270-nerd sizes=12 ;;
    *) echo "kitty-font: no font $font" >&2; exit 2 ;;
esac
case $size in auto) ;; '' | *[!0-9.]* | *.*.*) echo "kitty-font: size $size?" >&2; exit 2 ;; esac
case $scale in '' | *[!0-9.]* | *.*.*)
    # the biggest monitor's: "1920x1080@60.00 at 0x0" ... "scale: 1.25" for each
    scale=$(hyprctl monitors 2> /dev/null | awk '
        /^[[:space:]]*[0-9]+x[0-9]+@/ { split($1, a, /[x@]/); px = a[1] * a[2] }
        /^[[:space:]]*scale:/ { if (px > best) { best = px; s = $2 } }
        END { print s }')
    case $scale in '' | *[!0-9.]* | *.*.*) scale=1 ;; esac
    ;;
esac
auto=""
if [ "$size" = auto ]; then
    auto=" auto"
    # the nearest to 16 of hyprland's pixels (a smooth one: its usual size)
    size=$(echo "$sizes" | awk -v s="$scale" -v u="$unit" '{
        for (i = 1; i <= NF; i++) { d = (u == "px" ? $i / s : 16) - 16; if (d < 0) d = -d
            if (i == 1 || d < bd) { bd = d; b = $i } }
        print b }')
fi

# there? (kawt's own comes with kawt: a new one in its folder, fontconfig's list made again)
there() { fc-list "$family" family 2> /dev/null | grep -q .; }
if command -v fc-list > /dev/null && ! there; then
    [ -z "$pkg" ] && fc-cache "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/kawt" > /dev/null 2>&1
    there || { echo "missing ${pkg:-kawt}"; exit 4; }
fi

if [ "$unit" = px ]; then
    # points that land on whole screen pixels: px * 72 / dpi, in 64ths, down (a hair under a
    # pixel rounds to it in freetype; one over makes kitty's lines a pixel taller)
    pt=$(awk -v px="$size" -v s="$scale" 'BEGIN {
        s = int(s * 120 + 0.5) / 120 # as wayland has it, in 120ths (hyprctl says 1.33 for 4/3)
        dpi = int(96 * s + 0.001); n = int(px * 4608 / dpi + 0.0001)
        t = sprintf("%.6f", n / 64); sub(/0+$/, "", t); sub(/\.$/, "", t); printf "%s", t }')
    why="# $size screen pixels at scale $scale: every pixel of the font on one of the screen's"
else
    pt=$size
    why="# smooth: any size"
fi

new=$(
    printf '# kawt-font: %s %s%s\n' "$font" "$size" "$auto"
    printf '# kawt: settings -> look -> terminal writes this file (gone: kitty.conf, plex 11 pt)\n'
    printf '%s\n' "$why"
    printf 'font_family      %s\n' "$family"
    printf 'bold_font        auto\n'
    printf 'font_size        %s\n' "$pt"
    [ "$unit" = px ] && printf 'modify_font      cell_height 100%%\n'
)
[ -f "$file" ] && [ "$(cat "$file")" = "$new" ] && exit 0
mkdir -p "$conf" && printf '%s\n' "$new" > "$file" || exit 1
# every kitty: its config again, the font with it
pkill -USR1 -x kitty 2> /dev/null
exit 0
