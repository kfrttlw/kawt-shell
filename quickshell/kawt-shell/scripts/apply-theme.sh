#!/bin/sh
# usage: apply-theme.sh <dir> <name> <content> [<name> <content> ...]
# Writes each <content> to <dir>/<name>; an absolute <name> is written as-is if its directory exists.
# Pseudo names:
#   @pts        content is escape sequences, sent to every terminal we own (recolors them live)
#   @hyprreload reload Hyprland so it picks up the new border colors (hyprland.lua)
#   @hyprkeyword content is "option value" lines, set at once with hyprctl keyword (hyprland.conf:
#               no reload needed)
#   @gtk        content is "dark" or "light" (+ " live" on a switch): the gtk theme to match, set
#               only where install.sh linked ~/.config/gtk-3.0/gtk.css to kawt's; live, open gtk
#               apps read their colors and icons again (gtk does that when the theme changes)

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
        @hyprkeyword)
            printf '%s\n' "$content" | while read -r key value; do
                [ -n "$key" ] && hyprctl keyword "$key" "$value" > /dev/null 2>&1
            done
            ;;
        @gtk)
            css=${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/gtk.css
            [ -L "$css" ] && [ "$(readlink -f "$css")" = "$(readlink -f "$dir/gtk-3.css")" ] || continue
            command -v gsettings > /dev/null || continue
            s=org.gnome.desktop.interface
            case $content in
                light*) theme=adw-gtk3 scheme=default ;;
                *) theme=adw-gtk3-dark scheme=prefer-dark ;;
            esac
            case $content in
                *live) # off and on again: the same name wouldn't make them look
                    gsettings set $s gtk-theme Adwaita
                    gsettings set $s icon-theme hicolor
                    ;;
            esac
            gsettings set $s gtk-theme "$theme"
            gsettings set $s color-scheme "$scheme"
            [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/icons/kawt" ] && gsettings set $s icon-theme kawt
            ;;
        /*)
            [ -d "$(dirname "$name")" ] && printf '%s\n' "$content" > "$name"
            ;;
        */*)
            mkdir -p "$dir/${name%/*}" && printf '%s\n' "$content" > "$dir/$name"
            ;;
        *)
            printf '%s\n' "$content" > "$dir/$name"
            ;;
    esac
done
