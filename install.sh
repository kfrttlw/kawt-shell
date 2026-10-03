#!/usr/bin/env bash
# kawt installer: links the configs from this repo into ~/.config.
# Anything already there is kept as <name>.bak.<date>, nothing is deleted.
#
#   ./install.sh            install
#   ./install.sh --dry-run  only show what would happen

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
config=${XDG_CONFIG_HOME:-$HOME/.config}
stamp=$(date +%Y%m%d-%H%M%S)
dry=0
[[ ${1:-} == "--dry-run" || ${1:-} == "-n" ]] && dry=1

dim=$'\e[2m' acc=$'\e[1m' warn=$'\e[31m' off=$'\e[0m'
say() { printf '%s\n' "$*"; }
step() { printf '%s[%s]%s %s\n' "$acc" "$1" "$off" "$2"; }
run() {
    if ((dry)); then
        printf '%s  $ %s%s\n' "$dim" "$*" "$off"
    else
        "$@"
    fi
}

# link <file or dir in repo> <target path>
link() {
    local src=$repo/$1 dst=$2
    if [[ -L $dst && $(readlink -f "$dst") == "$(readlink -f "$src")" ]]; then
        step " ok " "$dst"
        return
    fi
    run mkdir -p "$(dirname "$dst")"
    if [[ -L $dst ]]; then
        run rm "$dst"
    elif [[ -e $dst ]]; then
        run mv "$dst" "$dst.bak.$stamp"
        step "save" "$dst -> $(basename "$dst").bak.$stamp"
    fi
    run ln -s "$src" "$dst"
    step "link" "$dst"
}

# append <line> to <file> unless <marker> is already in it
append_once() {
    local file=$1 marker=$2 line=$3
    # anywhere in the file, but not in a commented-out line (-- for lua, # for hyprlang)
    if grep -vE '^[[:space:]]*(--|#)' "$file" | grep -qF "$marker"; then
        step " ok " "$file already loads kawt"
        return
    fi
    run cp "$file" "$file.bak.$stamp"
    if ((dry)); then
        printf '%s  >> %s%s\n' "$dim" "$line" "$off"
    else
        printf '\n%s\n' "$line" >> "$file"
    fi
    step "edit" "$file (+1 line, backup: $(basename "$file").bak.$stamp)"
}

say "${acc}kawt${off} ${dim}// installing from $repo${off}"
((dry)) && say "${dim}dry run: nothing will be changed${off}"
say ""

link quickshell/kawt-shell "$config/quickshell/kawt-shell"
link kitty/kitty.conf "$config/kitty/kitty.conf"

# Hyprland: keep the user's config, just make it load kawt's binds
if [[ -f $config/hypr/hyprland.lua ]]; then
    if grep -qE '^[^-]*require\("kawt"\)' "$config/hypr/hyprland.lua"; then
        say "${warn}hyprland.lua still has require(\"kawt\") from an older setup: delete that line${off}"
    fi
    append_once "$config/hypr/hyprland.lua" "kawt-shell/hypr/kawt.lua" \
        'dofile(os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/kawt.lua")'
elif [[ -f $config/hypr/hyprland.conf ]]; then
    append_once "$config/hypr/hyprland.conf" "kawt-shell/hypr/kawt.conf" \
        'source = ~/.config/quickshell/kawt-shell/hypr/kawt.conf'
else
    step "skip" "no hyprland config found"
fi

# dependencies: only report, never install anything
say ""
missing=()
for cmd in qs hyprctl kitty brightnessctl curl; do
    command -v "$cmd" > /dev/null || missing+=("$cmd")
done
fc-list 2> /dev/null | grep -q "JetBrainsMono Nerd Font" || missing+=("ttf-jetbrains-mono-nerd")
if ((${#missing[@]})); then
    say "${warn}missing:${off} ${missing[*]}"
    say "${dim}  arch: sudo pacman -S quickshell kitty brightnessctl ttf-jetbrains-mono-nerd${off}"
else
    say "${dim}all dependencies found${off}"
fi
[[ -d /usr/share/icons/Papirus-Dark || -d $HOME/.local/share/icons/Papirus-Dark ]] ||
    say "${warn}no Papirus icons:${off} app icons will show as letters ${dim}(sudo pacman -S papirus-icon-theme)${off}"
say "${dim}optional: ollama (ai panel), awww (wallpapers), power-profiles-daemon${off}"
say ""
say "done. restart the shell:  ${acc}pkill qs; qs -c kawt-shell &${off}"
