#!/usr/bin/env bash
# kawt installer: links the configs from this repo into ~/.config and makes Hyprland load kawt.
#
# It checks everything first and changes nothing if a check fails. Existing configs are
# replaced, but never deleted: they are moved to ~/.local/state/kawt/backups/<date>/,
# and --uninstall puts them back.
#
#   ./install.sh               check, then install
#   ./install.sh --dry-run     check, then only print what would happen
#   ./install.sh --force       install even if checks failed
#   ./install.sh --uninstall   remove kawt's links and line, restore the latest backup
#   ./install.sh --help

set -uo pipefail
# (no `set -e`: every step checks its own result, so one failing command can't stop the
# script halfway through with half the files moved)

# ------------------------------------------------------------------ setup
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
config=${XDG_CONFIG_HOME:-$HOME/.config}
state=${XDG_STATE_HOME:-$HOME/.local/state}/kawt
stamp=$(date +%Y%m%d-%H%M%S)
backup=$state/backups/$stamp

qs_dst=$config/quickshell/kawt-shell
kitty_dst=$config/kitty/kitty.conf
hypr_lua=$config/hypr/hyprland.lua
hypr_conf=$config/hypr/hyprland.conf
# zsh prompt: one guarded line at the end of .zshrc, after oh-my-zsh, so it wins over any
# ZSH_THEME wherever oh-my-zsh is installed (or without it)
zshrc=${ZDOTDIR:-$HOME}/.zshrc
marker_zsh="kawt-shell/zsh/kawt.zsh-theme"
line_zsh='[[ -r ~/.config/quickshell/kawt-shell/zsh/kawt.zsh-theme ]] && source ~/.config/quickshell/kawt-shell/zsh/kawt.zsh-theme # kawt prompt'
marker_lua="kawt-shell/hypr/kawt.lua"
marker_conf="kawt-shell/hypr/kawt.conf"
line_lua='pcall(dofile, os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/kawt.lua")'
line_conf='source = ~/.config/quickshell/kawt-shell/hypr/kawt.conf'

mode=install dry=0 force=0
for arg in "$@"; do
    case $arg in
        -n | --dry-run) dry=1 ;;
        -f | --force) force=1 ;;
        -u | --uninstall) mode=uninstall ;;
        -h | --help)
            sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'unknown option: %s (see --help)\n' "$arg" >&2
            exit 2
            ;;
    esac
done

if [[ -t 1 ]]; then
    dim=$'\e[2m' acc=$'\e[1m' red=$'\e[31m' off=$'\e[0m'
else
    dim='' acc='' red='' off=''
fi
say() { printf '%s\n' "$*"; }
short() { printf '%s' "${1//"$HOME"/\~}"; } # /home/you/x -> ~/x, for display only
step() { printf '%s[%s]%s %s\n' "$acc" "$1" "$off" "$(short "$2")"; }
note() { printf '       %s%s%s\n' "$dim" "$(short "$1")" "$off"; }

errors=0
pass() { step "pass" "$1"; }
fail() {
    step "fail" "${red}$1${off}"
    [[ -n ${2:-} ]] && note "$2"
    errors=$((errors + 1))
    return 0
}
warn() {
    step "warn" "$1"
    [[ -n ${2:-} ]] && note "$2"
    return 0
}

# run a command; in --dry-run skip it (the [save]/[link]/[edit] lines say what would happen)
run() {
    ((dry)) && return 0
    "$@"
}

# does <file> load kawt? (a real line, not a commented-out one: -- in lua, # in hyprlang)
# no `grep -q` after a pipe: it exits early, the writer gets SIGPIPE and pipefail reports a failure
loads_kawt() {
    [[ -f $1 ]] || return 1
    grep -vE '^[[:space:]]*(--|#)' "$1" | grep -F "$2" > /dev/null
}

# resolved target of a link, empty if it is broken or loops
resolve() { readlink -e -- "$1" 2> /dev/null || true; }

# move <path> into the backup folder, keeping its place relative to $HOME
stash() {
    local path=$1 rel
    rel=${path#"$HOME"/}
    run mkdir -p "$(dirname "$backup/$rel")" || return 1
    run mv -- "$path" "$backup/$rel" || return 1
    step "save" "$path"
    note "-> $backup/$rel"
}

# copy (not move) a file into the backup folder; used before editing it in place
stash_copy() {
    local path=$1 rel
    rel=${path#"$HOME"/}
    run mkdir -p "$(dirname "$backup/$rel")" || return 1
    run cp -p -- "$path" "$backup/$rel" || return 1
}

# an older kawt set ZSH_THEME="kawt" (keeping the old value in a comment) and linked the theme
# into oh-my-zsh's custom folder; that missed oh-my-zsh installs outside ~/.oh-my-zsh.
# Put the old ZSH_THEME back and drop the link.
undo_old_zsh_setup() {
    local d
    for d in "${ZSH_CUSTOM:-}" "${ZSH:-$HOME/.oh-my-zsh}/custom" "$HOME/.oh-my-zsh/custom"; do
        if [[ -n $d && -L $d/themes/kawt.zsh-theme ]]; then
            run rm -- "$d/themes/kawt.zsh-theme" && step "rm" "$d/themes/kawt.zsh-theme (old link)"
        fi
    done
    if [[ -f $zshrc ]] && grep -E '^ZSH_THEME="kawt" # kawt, was: ' "$zshrc" > /dev/null; then
        stash_copy "$zshrc" && run sed -i -E 's/^ZSH_THEME="kawt" # kawt, was: (.*)$/ZSH_THEME=\1/' "$zshrc" && step "edit" "$zshrc (ZSH_THEME back to what it was)"
    fi
}

# ------------------------------------------------------------------ uninstall
if [[ $mode == uninstall ]]; then
    say "${acc}kawt${off} ${dim}// uninstalling${off}"
    ((dry)) && say "${dim}dry run: nothing will be changed${off}"
    say ""
    # the oldest backup that has a file holds its version from before kawt
    original() {
        local rel=$1 dir
        for dir in "$state"/backups/*/; do
            [[ -e $dir$rel ]] && { printf '%s' "$dir$rel"; return 0; }
        done
        return 1
    }

    for dst in "$qs_dst" "$kitty_dst"; do
        if [[ -L $dst ]]; then
            run rm -- "$dst" && step "rm" "$dst (link)"
        elif [[ -e $dst ]]; then
            step "keep" "$dst is not a kawt link, left alone"
            continue
        fi
        if orig=$(original "${dst#"$HOME"/}"); then
            run mkdir -p "$(dirname "$dst")" && run cp -a -- "$orig" "$dst" && step "back" "$dst"
        fi
    done

    undo_old_zsh_setup
    if [[ -f $zshrc ]] && grep -F "$marker_zsh" "$zshrc" > /dev/null; then
        stash_copy "$zshrc" && run sed -i "\|$marker_zsh|d" "$zshrc" && step "edit" "$zshrc (kawt prompt line removed)"
    fi

    for f in "$hypr_lua" "$hypr_conf"; do
        [[ -f $f ]] || continue
        if grep -F -e "$marker_lua" -e "$marker_conf" "$f" > /dev/null; then
            stash_copy "$f" && run sed -i -e "\|$marker_lua|d" -e "\|$marker_conf|d" "$f" && step "edit" "$f (kawt line removed)"
        fi
    done
    say ""
    say "done. ${dim}settings and notes in $(short "$state") were kept.${off}"
    exit 0
fi

# ------------------------------------------------------------------ 1. checks
say "${acc}kawt${off} ${dim}// installing from $(short "$repo")${off}"
((dry)) && say "${dim}dry run: nothing will be changed${off}"
say ""
say "${dim}-- checks --${off}"

# the repo itself
missing_files=()
for f in quickshell/kawt-shell/shell.qml quickshell/kawt-shell/hypr/kawt.lua quickshell/kawt-shell/hypr/kawt.conf kitty/kitty.conf quickshell/kawt-shell/zsh/kawt.zsh-theme; do
    [[ -f $repo/$f ]] || missing_files+=("$f")
done
if ((${#missing_files[@]})); then
    fail "repo is incomplete" "missing: ${missing_files[*]}"
else
    pass "repo files"
fi

# the repo must not live where the links go: linking would replace it with a link to itself
for target in "$qs_dst" "$config/kitty"; do
    real=$(resolve "$target")
    for t in "$target" ${real:+"$real"}; do
        if [[ $repo/ == "$t"/* ]]; then
            fail "the repo is inside $target" "move it out first: mv \"$repo\" ~/kawt && cd ~/kawt && ./install.sh"
            break 2
        fi
    done
done

# programs and packages; everything missing ends up in one pacman line
pkgs=()
need() { # need <0|1> <name> <package> <what it is for>
    if [[ $1 == 1 ]]; then
        pass "$2"
    else
        fail "$2 not found" "$4"
        pkgs+=("$3")
    fi
}
has() { command -v "$1" > /dev/null && echo 1 || echo 0; }
font_ok=0
fc-list : family 2> /dev/null | grep -F "JetBrainsMono Nerd Font" > /dev/null && font_ok=1
icons_ok=0
for d in /usr/share/icons/Papirus-Dark "$HOME/.local/share/icons/Papirus-Dark" "$HOME/.icons/Papirus-Dark"; do
    [[ -d $d ]] && icons_ok=1
done

need "$(has qs)" "quickshell" quickshell "the shell itself"
need "$(has hyprctl)" "hyprland" hyprland "the compositor"
need "$(has kitty)" "kitty" kitty "the terminal kawt configures"
need "$font_ok" "JetBrainsMono Nerd Font" ttf-jetbrains-mono-nerd "the font of the bar and of kitty"
need "$icons_ok" "Papirus icons" papirus-icon-theme "app icons in the launcher, dock and tray"
need "$(has notify-send)" "notify-send" libnotify "todo reminders"
need "$(has grim)" "grim" grim "screenshots"
need "$(has slurp)" "slurp" slurp "picking a screenshot area"
need "$(has wl-copy)" "wl-clipboard" wl-clipboard "screenshots and copies to the clipboard"
need "$(has cliphist)" "cliphist" cliphist "clipboard history (super+shift+v)"
need "$(has wf-recorder)" "wf-recorder" wf-recorder "screen recording (super+shift+r)"
# brightness only matters where there is a backlight (laptops)
if compgen -G "/sys/class/backlight/*" > /dev/null; then
    need "$(has brightnessctl)" "brightnessctl" brightnessctl "screen brightness"
fi

# hyprland config
if [[ -f $hypr_lua ]]; then
    if grep -vE '^[[:space:]]*--' "$hypr_lua" | grep -E 'require[[:space:]]*\(?[[:space:]]*["'"'"']kawt' > /dev/null; then
        fail "hyprland.lua has an old require(\"kawt\") line" "delete it: the file it loads is gone and it breaks the config"
    else
        pass "hyprland.lua"
    fi
    # if a lua compiler is around, make sure the config parses *before* we touch it
    luac=$(command -v luac || command -v luac5.4 || command -v luac5.3 || true)
    if [[ -n $luac ]] && ! "$luac" -p -- "$hypr_lua" > /dev/null 2>&1; then
        fail "hyprland.lua already has a syntax error" "see: $luac -p $hypr_lua"
    fi
elif [[ -f $hypr_conf ]]; then
    pass "hyprland.conf"
else
    warn "no hyprland config found" "kawt binds won't be added"
fi

# zsh is optional: with it, kawt also brings its prompt
if command -v zsh > /dev/null; then
    pass "zsh (the kawt prompt will be added to ${zshrc/#$HOME/\~})"
else
    warn "no zsh" "the kawt prompt is skipped"
fi

# leftovers from older kawt setups: harmless on their own
for f in "$config/hypr/kawt.lua" "$config/hypr/kawt-colors.lua"; do
    [[ -e $f ]] && warn "old file $f" "not used anymore, can be deleted"
done

say "${dim}optional: ollama (ai panel), awww (wallpapers), cava (sound bars), power-profiles-daemon${off}"
say ""

if ((errors)); then
    if ((force)); then
        say "${red}$errors check(s) failed${off}, continuing because of --force"
    else
        say "${red}$errors check(s) failed: nothing was changed.${off}"
        ((${#pkgs[@]})) && say "install what's missing:  ${acc}sudo pacman -S --needed ${pkgs[*]}${off}"
        say "then run ./install.sh again ${dim}(or --force to install anyway)${off}"
        exit 1
    fi
fi

# ------------------------------------------------------------------ 2. install
say "${dim}-- install --${off}"
failed=0

# link <path in repo> <target>: replaces whatever is at <target>, keeping a backup
link() {
    local src=$repo/$1 dst=$2
    if [[ -L $dst && $(resolve "$dst") == "$(resolve "$src")" ]]; then
        step " ok " "$dst"
        return 0
    fi
    run mkdir -p "$(dirname "$dst")" || return 1
    if [[ -L $dst ]]; then
        # an old, broken or looping link: nothing to keep
        run rm -- "$dst" || return 1
    elif [[ -e $dst ]]; then
        stash "$dst" || return 1
    fi
    run ln -s -- "$src" "$dst" || return 1
    step "link" "$dst"
}

link quickshell/kawt-shell "$qs_dst" || { fail "could not link $qs_dst"; failed=1; }
link kitty/kitty.conf "$kitty_dst" || { fail "could not link $kitty_dst"; failed=1; }

# make <file> load kawt with <line>, unless it already does
hook() {
    local file=$1 marker=$2 line=$3
    if loads_kawt "$file" "$marker"; then
        # an older installer wrote a bare dofile(...): a broken kawt.lua then took the whole
        # config down. swap that line for the pcall version.
        if [[ $marker == "$marker_lua" ]] && grep -vE '^[[:space:]]*--' "$file" | grep -F "$marker" | grep -v 'pcall' > /dev/null; then
            stash_copy "$file" || return 1
            if ((!dry)); then
                local tmp=$file.kawt-tmp l
                while IFS= read -r l || [[ -n $l ]]; do
                    if [[ $l == *"$marker"* && $l != *pcall* && ! $l =~ ^[[:space:]]*-- ]]; then
                        printf '%s\n' "$line"
                    else
                        printf '%s\n' "$l"
                    fi
                done < "$file" > "$tmp" && cat "$tmp" > "$file" && rm -f "$tmp" || return 1
            fi
            step "edit" "$file (kawt line now wrapped in pcall)"
            return 0
        fi
        step " ok " "$file loads kawt"
        return 0
    fi
    stash_copy "$file" || return 1
    if ((dry)); then
        note "+ $line"
    else
        printf '\n%s\n' "$line" >> "$file" || return 1
    fi
    step "edit" "$file (+1 line)"
}

if [[ -f $hypr_lua ]]; then
    hook "$hypr_lua" "$marker_lua" "$line_lua" || { fail "could not edit $hypr_lua"; failed=1; }
elif [[ -f $hypr_conf ]]; then
    hook "$hypr_conf" "$marker_conf" "$line_conf" || { fail "could not edit $hypr_conf"; failed=1; }
fi

# zsh: the prompt line at the end of .zshrc (created if there is none yet)
if command -v zsh > /dev/null; then
    undo_old_zsh_setup
    [[ -f $zshrc ]] || run touch "$zshrc"
    hook "$zshrc" "$marker_zsh" "$line_zsh" || { fail "could not edit $zshrc"; failed=1; }
fi

# ------------------------------------------------------------------ 3. verify
if ((!dry)); then
    say ""
    say "${dim}-- verify --${off}"
    if [[ -f $qs_dst/shell.qml ]]; then pass "quickshell finds kawt"; else fail "$qs_dst/shell.qml is not reachable"; failed=1; fi
    if [[ -f $kitty_dst ]]; then pass "kitty finds its config"; else fail "$kitty_dst is not reachable"; failed=1; fi
    if command -v zsh > /dev/null; then
        if loads_kawt "$zshrc" "$marker_zsh" && [[ -r $qs_dst/zsh/kawt.zsh-theme ]]; then pass "zsh loads the kawt prompt"; else fail "the kawt prompt is not reachable from $zshrc"; failed=1; fi
    fi
    if [[ -f $hypr_lua ]]; then
        if loads_kawt "$hypr_lua" "$marker_lua"; then pass "hyprland loads kawt"; else fail "hyprland.lua doesn't load kawt"; failed=1; fi
    elif [[ -f $hypr_conf ]]; then
        if loads_kawt "$hypr_conf" "$marker_conf"; then pass "hyprland loads kawt"; else fail "hyprland.conf doesn't load kawt"; failed=1; fi
    fi
fi

say ""
if ((failed)); then
    say "${red}something went wrong${off}, see above. to undo: ./install.sh --uninstall"
    exit 1
fi
if ((dry)); then
    say "dry run done, nothing was changed."
    exit 0
fi
[[ -d $backup ]] && say "${dim}old configs are in $(short "$backup")  (undo: ./install.sh --uninstall)${off}"
say "done. restart the shell:  ${acc}qs kill -c kawt-shell; qs -c kawt-shell -d${off}"
if command -v zsh > /dev/null; then
    say "the new prompt shows up in new terminals ${dim}(or now: exec zsh)${off}"
fi
exit 0
