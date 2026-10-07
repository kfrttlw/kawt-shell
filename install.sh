#!/usr/bin/env bash
# kawt installer: puts kawt on an Arch machine. A menu asks what to install (everything, only
# the shell, or part by part), installs what's missing with pacman (and an AUR helper for the
# rest), can update the whole system first, then links the configs from this repo into
# ~/.config and makes Hyprland load kawt. Existing configs are moved to
# ~/.local/state/kawt/backups/<date>/, never deleted; --uninstall puts them back.
#
#   ./install.sh                 the menu
#   ./install.sh --all           everything, no menu
#   ./install.sh --shell-only    only the shell (bar, panels, lock) and its hyprland binds
#   ./install.sh --no-packages   don't touch pacman, only link the configs
#   ./install.sh --no-update     install what's missing, without updating the system
#   ./install.sh --yes           ask nothing (pacman too: --noconfirm)
#   ./install.sh --dry-run       show what would happen, change nothing
#   ./install.sh --uninstall     remove kawt's links and lines, put the old configs back
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
fastfetch_dst=$config/fastfetch/config.jsonc
fastfetch_src=$state/theme/fastfetch.jsonc # rewritten by kawt on every theme switch
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

# the parts, in menu order: id | name | what it is
parts=(
    "shell|shell|the bar, panels, launcher, lock screen, ai (quickshell)"
    "hypr|hyprland|kawt's binds and border colors in your hyprland config"
    "kitty|kitty|the terminal, in the theme's colors"
    "zsh|zsh prompt|┌[user@host]─[~/dir]─[branch]  in the theme's colors"
    "fastfetch|fastfetch|system info with the little thinkpad"
    "extras|extras|ollama (ai), cava, fortune, wallpapers, night light, power"
)
# packages per part; "a|b" = the first of them the repos have
pkgs_shell=(quickshell hyprland ttf-jetbrains-mono-nerd papirus-icon-theme libnotify grim slurp wl-clipboard cliphist wf-recorder ffmpeg pipewire wireplumber upower glib2)
pkgs_hypr=()
pkgs_kitty=(kitty)
pkgs_zsh=(zsh git)
pkgs_fastfetch=(fastfetch)
pkgs_extras=(ollama cava fortune-mod "awww|swww" hyprsunset power-profiles-daemon)

mode=install dry=0 yes=0 preset="" packages=1 update=1
for arg in "$@"; do
    case $arg in
        -a | --all) preset=all ;;
        -s | --shell-only) preset=shell ;;
        --no-packages) packages=0 ;;
        --no-update) update=0 ;;
        -y | --yes) yes=1 ;;
        -n | --dry-run) dry=1 ;;
        -u | --uninstall) mode=uninstall ;;
        -h | --help)
            sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'unknown option: %s (see --help)\n' "$arg" >&2
            exit 2
            ;;
    esac
done

if [[ -t 1 ]]; then
    dim=$'\e[2m' acc=$'\e[1m' red=$'\e[31m' nub=$'\e[38;2;226;35;26m' off=$'\e[0m'
else
    dim='' acc='' red='' nub='' off=''
fi
say() { printf '%s\n' "$*"; }
short() { printf '%s' "${1//"$HOME"/\~}"; } # /home/you/x -> ~/x, for display only
step() { printf '%s[%s]%s %s\n' "$acc" "$1" "$off" "$(short "$2")"; }
note() { printf '       %s%s%s\n' "$dim" "$(short "$1")" "$off"; }
section() { printf '\n%s-- %s --%s\n' "$dim" "$1" "$off"; }

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

# run a command; in --dry-run only show it
run() {
    if ((dry)); then
        note "would run: $*"
        return 0
    fi
    "$@"
}

banner() {
    say ""
    say "${dim}  ____________${off}"
    say "${dim} | ${off}${acc}>_${off}${dim}         |${off}    ${acc}kawt${off} ${dim}// $1${off}"
    say "${dim} |            |${off}    ${dim}a hyprland rice that looks like an old terminal${off}"
    say "${dim} |____________|${off}"
    say "${dim}/ :::::${off}${nub}●${off}${dim}:::::: \\${off}"
    say "${dim}\\______________/${off}"
}

# ------------------------------------------------------------------ the menu
# keys come from the terminal itself, so this works with the script piped into bash too
can_ask() { ((!yes)) && [[ -r /dev/tty && -w /dev/tty ]] && { : < /dev/tty; } 2> /dev/null; }

key() {
    local k rest
    IFS= read -rsn1 k < /dev/tty || return 1
    if [[ $k == $'\e' ]]; then
        IFS= read -rsn2 -t 0.05 rest < /dev/tty
        case $rest in
            '[A') echo up ;;
            '[B') echo down ;;
            *) echo esc ;;
        esac
    elif [[ -z $k ]]; then
        echo enter
    elif [[ $k == ' ' ]]; then
        echo space
    else
        echo "$k"
    fi
}

# the cursor back on, lines wrapping again (the menus switch both off)
cursor_back() { printf '\e[?25h\e[?7h' 2> /dev/null > /dev/tty; } # stderr first: no tty, no message

# A menu line must fit the terminal: a wrapped one takes two rows, and the menu, which moves up
# one row per item to draw itself again, then draws over the wrong lines. So every line is cut
# to the width (measured at each redraw: the window may change), and wrapping is off meanwhile.
fit() { # fit <text> <room>: the text, cut with … if longer than room
    local t=$1 room=$2
    ((room < 1)) && return
    ((${#t} > room)) && t="${t:0:room-1}…"
    printf '%s' "$t"
}
cols() {
    local c
    c=$(stty size < /dev/tty 2> /dev/null | cut -d' ' -f2)
    ((c > 0)) 2> /dev/null && echo "$c" || echo 80
}
trap cursor_back EXIT
quit() {
    cursor_back
    say ""
    say "${dim}nothing was changed.${off}"
    exit 130
}
trap quit INT

# choose <var> "name|what" ... : ↑↓ (or j k) and enter; <var> gets the index
choose() {
    local -n chosen=$1
    shift
    local items=("$@") n=$# cur=${CHOOSE_AT:-0} i name what k room # CHOOSE_AT=<n>: start there
    printf '\e[?25l\e[?7l' > /dev/tty
    while :; do
        room=$(($(cols) - 21))
        for i in "${!items[@]}"; do
            name=${items[i]%%|*} what=$(fit "${items[i]#*|}" "$room")
            if ((i == cur)); then
                printf '\e[2K %s> %-16s%s %s\n' "$acc" "$name" "$off" "$what" > /dev/tty
            else
                printf '\e[2K   %-16s %s%s%s\n' "$name" "$dim" "$what" "$off" > /dev/tty
            fi
        done
        k=$(key) || quit
        case $k in
            up | k) cur=$(((cur + n - 1) % n)) ;;
            down | j) cur=$(((cur + 1) % n)) ;;
            enter) break ;;
            q | esc) quit ;;
        esac
        printf '\e[%dA' "$n" > /dev/tty
    done
    cursor_back
    chosen=$cur
}

# pick <array var of 0/1> "name|what" ... : ↑↓ move, space toggles, enter goes on
pick() {
    local -n _on=$1 # not `on`: picking the array named on would point it at itself
    shift
    local items=("$@") n=$# cur=0 i name what box k room
    printf '\e[?25l\e[?7l' > /dev/tty
    while :; do
        room=$(($(cols) - 21))
        for i in "${!items[@]}"; do
            name=${items[i]%%|*} what=$(fit "${items[i]#*|}" "$room")
            box="[ ]"
            ((_on[i])) && box="[x]"
            if ((i == cur)); then
                printf '\e[2K %s> %s %-12s%s %s\n' "$acc" "$box" "$name" "$off" "$what" > /dev/tty
            elif ((_on[i])); then
                printf '\e[2K   %s %-12s %s%s%s\n' "$box" "$name" "$dim" "$what" "$off" > /dev/tty
            else
                printf '\e[2K   %s%s %-12s %s%s\n' "$dim" "$box" "$name" "$what" "$off" > /dev/tty
            fi
        done
        k=$(key) || quit
        case $k in
            up | k) cur=$(((cur + n - 1) % n)) ;;
            down | j) cur=$(((cur + 1) % n)) ;;
            space | x) _on[cur]=$((1 - _on[cur])) ;;
            enter) break ;;
            q | esc) quit ;;
        esac
        printf '\e[%dA' "$n" > /dev/tty
    done
    cursor_back
}

# ask <question> [answer without a terminal]: yes / no, enter = yes. --yes says yes to all;
# with nobody to ask, the second argument decides (0 yes, 1 no; yes if left out)
ask() {
    local answer
    ((yes)) && return 0
    can_ask || return "${2:-0}"
    printf '%s %s[Y/n]%s ' "$1" "$dim" "$off" > /dev/tty
    IFS= read -r answer < /dev/tty
    [[ -z $answer || $answer == [yYдД]* ]]
}

# ------------------------------------------------------------------ helpers (configs)
loads_kawt() {
    # does <file> load kawt? (a real line, not a commented-out one: -- in lua, # in hyprlang)
    # no `grep -q` after a pipe: it exits early, the writer gets SIGPIPE and pipefail reports a failure
    [[ -f $1 ]] || return 1
    grep -vE '^[[:space:]]*(--|#)' "$1" | grep -F "$2" > /dev/null
}

resolve() { readlink -e -- "$1" 2> /dev/null || true; } # resolved target of a link, empty if broken

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
    run mkdir -p "$(dirname "$backup/$rel")" > /dev/null || return 1
    run cp -p -- "$path" "$backup/$rel" > /dev/null || return 1
}

# link <source> <target>: replaces whatever is at <target>, keeping a backup
link() {
    local src=$1 dst=$2
    if [[ -L $dst && $(resolve "$dst") == "$(resolve "$src")" ]]; then
        step " ok " "$dst"
        return 0
    fi
    run mkdir -p "$(dirname "$dst")" || return 1
    if [[ -L $dst ]]; then
        run rm -- "$dst" || return 1 # an old, broken or looping link: nothing to keep
    elif [[ -e $dst ]]; then
        stash "$dst" || return 1
    fi
    run ln -s -- "$src" "$dst" || return 1
    step "link" "$dst"
}

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

# an older kawt set ZSH_THEME="kawt" (keeping the old value in a comment) and linked the theme
# into oh-my-zsh's custom folder. Put the old ZSH_THEME back and drop the link.
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
    banner "uninstalling"
    ((dry)) && say "${dim}dry run: nothing will be changed${off}"
    say ""
    # the oldest backup that has a file holds its version from before kawt
    original() {
        local rel=$1 dir
        for dir in "$state"/backups/*/; do
            [[ -e $dir$rel ]] && {
                printf '%s' "$dir$rel"
                return 0
            }
        done
        return 1
    }

    for dst in "$qs_dst" "$kitty_dst" "$fastfetch_dst"; do
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
    say "done. ${dim}packages stay installed; settings and notes in $(short "$state") were kept.${off}"
    exit 0
fi

# ------------------------------------------------------------------ 0. who and where
banner "installer"
((dry)) && say "${dim}dry run: nothing will be changed${off}"

if ((EUID == 0)); then
    say ""
    say "${red}run this as your own user, not as root${off} ${dim}(it asks for sudo itself, only for pacman)${off}"
    exit 1
fi

for f in quickshell/kawt-shell/shell.qml quickshell/kawt-shell/hypr/kawt.lua quickshell/kawt-shell/hypr/kawt.conf kitty/kitty.conf fastfetch/config.jsonc quickshell/kawt-shell/zsh/kawt.zsh-theme; do
    if [[ ! -f $repo/$f ]]; then
        say "${red}the repo is incomplete:${off} $f is missing"
        exit 1
    fi
done
# the repo must not live where the links go: linking would replace it with a link to itself
for target in "$qs_dst" "$config/kitty"; do
    real=$(resolve "$target")
    for t in "$target" ${real:+"$real"}; do
        if [[ $repo/ == "$t"/* ]]; then
            say "${red}the repo is inside $(short "$target")${off}"
            note "move it out first: mv \"$repo\" ~/kawt && cd ~/kawt && ./install.sh"
            exit 1
        fi
    done
done

# ------------------------------------------------------------------ 1. which system
# Arch and what's built on it (EndeavourOS, CachyOS, Manjaro...) get their packages installed.
# Anywhere else the package names are anyone's guess: kawt installs its configs there and lists
# what to get by hand (like caelestia and most rices do outside arch). Detected from
# /etc/os-release; the menu lets you say otherwise.
os_id=$(. /etc/os-release 2> /dev/null && printf '%s' "${ID:-}")
os_like=$(. /etc/os-release 2> /dev/null && printf '%s' "${ID_LIKE:-}")
os_name=$(. /etc/os-release 2> /dev/null && printf '%s' "${PRETTY_NAME:-${ID:-}}")
is_arch=0
[[ " $os_id $os_like " == *" arch "* ]] && command -v pacman > /dev/null && is_arch=1
if [[ -z $preset ]] && can_ask; then
    section "which system is this?"
    say "${dim}  looks like ${os_name:-an unknown one} · ↑↓ move · enter pick${off}"
    sys=0
    CHOOSE_AT=$((1 - is_arch)) choose sys "arch|or based on it (endeavouros, cachyos, manjaro): installs packages too" \
        "something else|only kawt's configs, plus a list of what to install"
    if ((sys == 0)) && ! command -v pacman > /dev/null; then
        say "${red}no pacman here${off}, so kawt can only do its configs."
        is_arch=0
    else
        is_arch=$((sys == 0))
    fi
fi
if ((!is_arch)); then
    packages=0
    update=0
fi

# ------------------------------------------------------------------ 2. what
# on = which parts, in the order of `parts`
on=(1 1 1 1 1 0)
case $preset in
    all) on=(1 1 1 1 1 1) ;;
    shell) on=(1 1 0 0 0 0) ;;
    *)
        if can_ask; then
            which=0
            section "what should go on this machine?"
            say "${dim}  ↑↓ move · enter pick · q quit${off}"
            choose which "everything|shell, terminal, prompt, fastfetch and the extras" \
                "only the shell|the bar and panels + hyprland binds, nothing else" \
                "let me pick|part by part"
            case $which in
                0) on=(1 1 1 1 1 1) ;;
                1) on=(1 1 0 0 0 0) ;;
                2)
                    section "parts"
                    say "${dim}  ↑↓ move · space on/off · enter go on${off}"
                    pick on "${parts[@]#*|}"
                    ;;
            esac
        fi
        ;;
esac
want() { # want <part id>: is it picked?
    local i
    for i in "${!parts[@]}"; do
        [[ ${parts[i]%%|*} == "$1" ]] && { ((on[i])); return; }
    done
    return 1
}

if ((packages)) && [[ -z $preset ]] && can_ask; then
    section "packages"
    say "${dim}  ↑↓ move · space on/off · enter go on${off}"
    opts=("$packages" "$update")
    pick opts "install them|what's missing, with pacman (quickshell from the aur if needed)" \
        "update first|the whole system too (pacman -Syu), as arch wants it"
    packages=${opts[0]}
    update=$((opts[0] && opts[1]))
fi

# ------------------------------------------------------------------ 3. packages
installed() { pacman -T -- "$1" > /dev/null 2>&1; } # also true for a package that provides it (quickshell-git)
in_repos() { pacman -Si -- "$1" > /dev/null 2>&1; }

# what the picked parts need (arch package names; "a|b" = the first one there is)
wanted=()
for id in shell hypr kitty zsh fastfetch extras; do
    want "$id" || continue
    declare -n list="pkgs_$id"
    wanted+=("${list[@]}")
    unset -n list
done
want shell && compgen -G "/sys/class/backlight/*" > /dev/null && wanted+=(brightnessctl)
want shell && compgen -G "/sys/class/bluetooth/*" > /dev/null && wanted+=(bluez bluez-utils)

repo_pkgs=() aur_pkgs=() have=0
if ((packages)); then
    for spec in "${wanted[@]}"; do
        IFS='|' read -ra alts <<< "$spec"
        found=0
        for p in "${alts[@]}"; do
            installed "$p" && { found=1; break; }
        done
        if ((found)); then
            have=$((have + 1))
            continue
        fi
        # power-profiles-daemon and tlp don't get along: keep tlp
        [[ ${alts[0]} == power-profiles-daemon ]] && installed tlp && continue
        pick_repo=""
        for p in "${alts[@]}"; do
            in_repos "$p" && { pick_repo=$p; break; }
        done
        if [[ -n $pick_repo ]]; then
            [[ " ${repo_pkgs[*]} " == *" $pick_repo "* ]] || repo_pkgs+=("$pick_repo")
        else
            [[ " ${aur_pkgs[*]} " == *" ${alts[0]} "* ]] || aur_pkgs+=("${alts[0]}")
        fi
    done
fi
aur_helper=$(command -v paru || command -v yay || true)

# The AUR is a shelf of build recipes; paru and yay fetch and build them for you. kawt only needs
# one thing from there (quickshell, when the repos don't have it), so without a helper it does
# the same by hand: get the recipe into ~/.cache/kawt/aur/<package>, build and install it with
# makepkg. aur_build <package> [rebuild]: rebuild = build it again although it's installed
aur_dir=${XDG_CACHE_HOME:-$HOME/.cache}/kawt/aur
aur_build() {
    local pkg=$1 dir=$aur_dir/$1 flag=--needed
    [[ ${2:-} == rebuild ]] && flag=-f
    if [[ -d $dir/.git ]]; then
        run git -C "$dir" pull -q --ff-only || return 1
    else
        run mkdir -p "$aur_dir" && run git clone -q "https://aur.archlinux.org/$pkg.git" "$dir" || return 1
    fi
    # -r: the build tools makepkg installs for this (cmake, ninja...) go again afterwards
    if ((dry)); then
        note "would run: cd $(short "$dir") && makepkg -sir $flag"
        return 0
    fi
    (cd "$dir" && makepkg -sir "$flag" "${noconfirm[@]}")
}

# an arch package name -> what to look for on another system
human() {
    case $1 in
        quickshell) echo "quickshell (see quickshell.org)" ;;
        ttf-jetbrains-mono-nerd) echo "JetBrainsMono Nerd Font" ;;
        papirus-icon-theme) echo "Papirus icons" ;;
        libnotify) echo "notify-send (libnotify)" ;;
        glib2) echo "gdbus (glib2)" ;;
        fortune-mod) echo "fortune" ;;
        "awww|swww") echo "awww or swww" ;;
        bluez-utils) ;;
        *) echo "$1" ;;
    esac
}
needs_list() {
    local p n out=()
    for p in "${wanted[@]}"; do
        n=$(human "$p")
        [[ -n $n ]] && out+=("$n")
    done
    local IFS=,
    printf '%s' "${out[*]}" | sed 's/,/, /g'
}

# An AUR quickshell is built against the Qt it found then. After a Qt update it has to be built
# again, or it warns "built against Qt X but the system has Qt Y" and may crash. So: is Qt
# (qt6-base) newer than the quickshell package? Prints that package's name if so.
# (Packages from the repos are rebuilt by Arch itself, and -bin ones can't be.)
stamp() { # stamp <package> "Install Date" | "Build Date": as seconds
    local d
    d=$(LC_ALL=C pacman -Qi -- "$1" 2> /dev/null | sed -n "s/^$2 *: //p")
    [[ -n $d ]] && date -d "$d" +%s 2> /dev/null
}
# Is quickshell built for an older Qt than the one installed? Prints "<package> <aur|arch>" if so.
#   aur   built here, before the Qt we have was installed: kawt builds it again
#   arch  from the repos, built by Arch before it built our Qt: Arch hasn't rebuilt it yet. It
#         always does within days ("Rebuild for Qt 6.11.1", "Qt 6.11.2 rebuild"...) and
#         `pacman -Syu` brings it; kawt only says so (building it here instead would be the same
#         compiling as Arch does, for a few days' difference)
stale_quickshell() {
    local q from qt qs
    command -v pacman > /dev/null || return 1
    q=$(pacman -Qq 2> /dev/null | grep -xE 'quickshell(-git)?' | head -n 1)
    [[ -n $q ]] || return 1
    if pacman -Qmq 2> /dev/null | grep -x "$q" > /dev/null; then
        from=aur
        qt=$(stamp qt6-base "Install Date") qs=$(stamp "$q" "Install Date")
    else
        from=arch
        qt=$(stamp qt6-base "Build Date") qs=$(stamp "$q" "Build Date")
    fi
    [[ -n $qt && -n $qs ]] && ((qt > qs)) || return 1
    printf '%s %s' "$q" "$from"
}

# pacman -Syu never looks at the AUR: an aur quickshell would stay at its version for good. So
# kawt asks the AUR itself (its rpc api: just a question, nothing is downloaded or changed) and
# builds the newer one. A -git package has no version to compare and is left alone.
aur_version() { # aur_version <package>: the version the AUR has now
    curl -s -m 10 "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=$1" 2> /dev/null | grep -o '"Version":"[^"]*"' | head -n 1 | cut -d'"' -f4
}
qs_have="" qs_update=""
if ((packages)) && pacman -Qmq 2> /dev/null | grep -x quickshell > /dev/null; then
    qs_have=$(pacman -Q quickshell 2> /dev/null | cut -d' ' -f2)
    v=$(aur_version quickshell)
    [[ -n $v && -n $qs_have ]] && (($(vercmp "$v" "$qs_have") > 0)) && qs_update=$v
fi
# quickshell already behind the installed Qt (see stale_quickshell)
stale_now=""
((packages)) && stale_now=$(stale_quickshell)
# without paru / yay an aur quickshell is (re)built here: that needs git and base-devel
if [[ -z $aur_helper ]] && { ((${#aur_pkgs[@]})) || [[ -n $qs_have ]]; }; then
    for p in git base-devel; do
        installed "$p" || [[ " ${repo_pkgs[*]} " == *" $p "* ]] || repo_pkgs+=("$p")
    done
fi

# ------------------------------------------------------------------ 4. the plan
section "plan"
names=()
for i in "${!parts[@]}"; do
    ((on[i])) && { p=${parts[i]#*|}; names+=("${p%%|*}"); }
done
if ((${#names[@]} == 0)); then
    say "nothing picked. ${dim}nothing was changed.${off}"
    exit 0
fi
printf '  %-9s %s\n' "system" "${os_name:-unknown}$( ((is_arch)) && printf ' (arch: packages included)' || printf ' (configs only)')"
printf '  %-9s %s\n' "install" "$(IFS=,; printf '%s' "${names[*]}" | sed 's/,/, /g')"
if ((packages)); then
    pac="sudo pacman -S$( ((update)) && printf 'yu')"
    if ((${#repo_pkgs[@]})); then
        printf '  %-9s %s %s\n' "packages" "$pac --needed" "${repo_pkgs[*]}"
    elif ((update)); then
        printf '  %-9s %s\n' "packages" "sudo pacman -Syu   ${dim}(everything else is there: $have)${off}"
    else
        printf '  %-9s %s\n' "packages" "${dim}all there ($have)${off}"
    fi
    if ((${#aur_pkgs[@]})); then
        printf '  %-9s %s\n' "aur" "${aur_pkgs[*]}  ${dim}$( [[ -n $aur_helper ]] && printf 'with %s' "${aur_helper##*/}" || printf 'built here with makepkg (no paru / yay needed)')${off}"
    fi
    [[ -n $qs_update ]] && printf '  %-9s %s\n' "update" "quickshell $qs_have → $qs_update  ${dim}(from the aur)${off}"
    [[ -n $stale_now && ${stale_now#* } == aur ]] && printf '  %-9s %s\n' "rebuild" "${stale_now% *}  ${dim}(built for an older Qt than yours)${off}"
elif ((!is_arch)); then
    printf '  %-9s %s\n' "packages" "${dim}${os_name:-this system} isn't arch: kawt can't install packages here${off}"
    printf '  %-9s %s\n' "get" "$(needs_list)"
else
    printf '  %-9s %s\n' "packages" "${dim}left alone${off}"
fi
printf '  %-9s %s\n' "then" "link the configs ${dim}(what's there now goes to $(short "$backup"))${off}"
say ""
if ! ask "go?"; then
    say "${dim}nothing was changed.${off}"
    exit 0
fi

# ------------------------------------------------------------------ 5. install packages
failed=0
noconfirm=()
((yes)) && noconfirm=(--noconfirm)
if ((packages)); then
    section "packages"
    if ((update)); then
        run sudo pacman -Syu --needed "${noconfirm[@]}" "${repo_pkgs[@]}" || { fail "pacman failed" "see above; then run ./install.sh again"; failed=1; }
    elif ((${#repo_pkgs[@]})); then
        run sudo pacman -S --needed "${noconfirm[@]}" "${repo_pkgs[@]}" || { fail "pacman failed" "see above; then run ./install.sh again"; failed=1; }
    fi
    if ((${#aur_pkgs[@]})); then
        if [[ -n $aur_helper ]]; then
            run "$aur_helper" -S --needed "${noconfirm[@]}" "${aur_pkgs[@]}" || { fail "${aur_helper##*/} failed" "see above"; failed=1; }
        else
            for p in "${aur_pkgs[@]}"; do
                note "$p: from the aur, built here (the recipe: https://aur.archlinux.org/packages/$p)"
                aur_build "$p" || { fail "building $p failed" "see above"; failed=1; }
            done
        fi
    fi
    if [[ -n $qs_update ]]; then
        note "quickshell $qs_have → $qs_update, from the aur"
        if [[ -n $aur_helper ]]; then
            run "$aur_helper" -S "${noconfirm[@]}" quickshell || { fail "updating quickshell failed" "see above"; failed=1; }
        else
            aur_build quickshell || { fail "updating quickshell failed" "see above"; failed=1; }
        fi
    fi
    # quickshell built for an older Qt (the update may have just brought a new one): build it again
    if s=$(stale_quickshell); then
        stale=${s% *} from=${s#* }
        if [[ $from == arch ]]; then
            warn "Arch hasn't rebuilt $stale for this Qt yet: it may crash until then" "the rebuild comes with sudo pacman -Syu, usually within days; kawt works meanwhile"
        elif [[ -n $aur_helper ]]; then
            note "Qt is newer than $stale: building $stale again against it"
            run "$aur_helper" -S --rebuild "${noconfirm[@]}" "$stale" || { fail "rebuilding $stale failed" "see above; until it works kawt may crash"; failed=1; }
        else
            note "Qt is newer than $stale: building $stale again against it"
            aur_build "$stale" rebuild || { fail "rebuilding $stale failed" "see above; until it works kawt may crash"; failed=1; }
        fi
    fi
    ((failed)) || pass "packages"
fi

# ------------------------------------------------------------------ 6. checks
section "checks"
# need_cmd <command> <what for>. On arch a missing one stops the install (the packages should be
# there by now); elsewhere it's a reminder: the configs go in anyway, kawt runs once it's there
need_cmd() {
    if command -v "$1" > /dev/null; then
        pass "$1"
    elif ((is_arch)); then
        fail "$1 not found" "$2"
    else
        warn "$1 not found" "$2"
    fi
}
if want shell; then
    need_cmd qs "the shell itself (package quickshell)"
    if ((!packages)) && s=$(stale_quickshell); then
        stale=${s% *}
        if [[ ${s#* } == arch ]]; then
            warn "$stale is built for an older Qt: Arch hasn't rebuilt it yet, it may crash" "the rebuild comes with sudo pacman -Syu, usually within days"
        else
            fix="./install.sh (it builds it again)"
            [[ -n $aur_helper ]] && fix="${aur_helper##*/} -S --rebuild $stale"
            warn "$stale was built before the last Qt update: it may crash" "build it again: $fix"
        fi
    fi
    need_cmd hyprctl "the compositor (package hyprland)"
    if fc-list : family 2> /dev/null | grep -F "JetBrainsMono Nerd Font" > /dev/null; then
        pass "JetBrainsMono Nerd Font"
    elif ((is_arch)); then
        fail "JetBrainsMono Nerd Font not found" "the font of everything (ttf-jetbrains-mono-nerd)"
    else
        warn "JetBrainsMono Nerd Font not found" "the font of everything: nerdfonts.com, JetBrainsMono"
    fi
    # NetworkManager isn't installed for you: next to iwd or systemd-networkd it can take the
    # network over. The wifi panel needs it, the rest of kawt doesn't
    if command -v nmcli > /dev/null; then
        systemctl is-active --quiet NetworkManager 2> /dev/null && pass "NetworkManager (wifi panel)" || warn "NetworkManager isn't running" "the wifi panel needs it: sudo systemctl enable --now NetworkManager"
    else
        warn "no NetworkManager: the wifi panel stays empty" "if you want it (and don't use iwd/networkd alone), install networkmanager"
    fi
fi
want kitty && need_cmd kitty "the terminal (package kitty)"
want fastfetch && need_cmd fastfetch "package fastfetch"
if [[ -f $hypr_lua ]]; then
    if grep -vE '^[[:space:]]*--' "$hypr_lua" | grep -E 'require[[:space:]]*\(?[[:space:]]*["'"'"']kawt' > /dev/null; then
        fail "hyprland.lua has an old require(\"kawt\") line" "delete it: the file it loads is gone and it breaks the config"
    fi
    # if a lua compiler is around, make sure the config parses *before* we touch it
    luac=$(command -v luac || command -v luac5.4 || command -v luac5.3 || true)
    if [[ -n $luac ]] && ! "$luac" -p -- "$hypr_lua" > /dev/null 2>&1; then
        fail "hyprland.lua already has a syntax error" "see: $luac -p $hypr_lua"
    fi
elif want hypr && [[ ! -f $hypr_conf ]]; then
    warn "no hyprland config found" "start hyprland once (it writes one), then run ./install.sh again for the binds"
fi
if ((errors)) && ((!dry)); then
    say ""
    say "${red}$errors check(s) failed:${off} kawt would not work like this, the configs were not linked."
    ((packages)) || say "install what's missing (or run ./install.sh without --no-packages), then again."
    exit 1
fi

# ------------------------------------------------------------------ 7. configs
section "configs"
if want shell; then
    link "$repo/quickshell/kawt-shell" "$qs_dst" || { fail "could not link $qs_dst"; failed=1; }
fi
if want kitty; then
    link "$repo/kitty/kitty.conf" "$kitty_dst" || { fail "could not link $kitty_dst"; failed=1; }
fi
if want fastfetch; then
    # fastfetch reads kawt's generated config (the theme's colors); until kawt has run once,
    # that is the repo's starting point
    if [[ ! -f $fastfetch_src ]]; then
        run mkdir -p "$(dirname "$fastfetch_src")" && run cp -- "$repo/fastfetch/config.jsonc" "$fastfetch_src"
    fi
    link "$fastfetch_src" "$fastfetch_dst" || { fail "could not link $fastfetch_dst"; failed=1; }
fi
if want hypr; then
    if [[ -f $hypr_lua ]]; then
        hook "$hypr_lua" "$marker_lua" "$line_lua" || { fail "could not edit $hypr_lua"; failed=1; }
    elif [[ -f $hypr_conf ]]; then
        hook "$hypr_conf" "$marker_conf" "$line_conf" || { fail "could not edit $hypr_conf"; failed=1; }
    fi
fi
if want zsh && command -v zsh > /dev/null; then
    undo_old_zsh_setup
    [[ -f $zshrc ]] || run touch "$zshrc"
    hook "$zshrc" "$marker_zsh" "$line_zsh" || { fail "could not edit $zshrc"; failed=1; }
fi

# ------------------------------------------------------------------ 8. services
# only asked, never just switched on
if ((!dry)); then
    if want shell && compgen -G "/sys/class/bluetooth/*" > /dev/null && command -v bluetoothctl > /dev/null && ! systemctl is-active --quiet bluetooth 2> /dev/null; then
        ask "bluetooth is off: start it now and at boot?" 1 && sudo systemctl enable --now bluetooth
    fi
    if want extras && command -v ollama > /dev/null && ! systemctl is-active --quiet ollama 2> /dev/null; then
        ask "start ollama (the ai panel's local model server) now and at boot?" 1 && sudo systemctl enable --now ollama
    fi
    if want extras && command -v powerprofilesctl > /dev/null && ! systemctl is-active --quiet power-profiles-daemon 2> /dev/null; then
        ask "start power-profiles-daemon (saver / balanced / perf in the battery panel)?" 1 && sudo systemctl enable --now power-profiles-daemon
    fi
fi

# ------------------------------------------------------------------ 9. verify
if ((!dry)); then
    section "verify"
    if want shell; then
        if [[ -f $qs_dst/shell.qml ]]; then pass "quickshell finds kawt"; else fail "$qs_dst/shell.qml is not reachable"; failed=1; fi
    fi
    if want kitty; then
        if [[ -f $kitty_dst ]]; then pass "kitty finds its config"; else fail "$kitty_dst is not reachable"; failed=1; fi
    fi
    if want fastfetch; then
        if [[ -f $fastfetch_dst ]]; then pass "fastfetch finds its config"; else fail "$fastfetch_dst is not reachable"; failed=1; fi
    fi
    if want zsh && command -v zsh > /dev/null; then
        if loads_kawt "$zshrc" "$marker_zsh"; then pass "zsh loads the kawt prompt"; else fail "the kawt prompt is not reachable from $zshrc"; failed=1; fi
    fi
    if want hypr; then
        if [[ -f $hypr_lua ]]; then
            if loads_kawt "$hypr_lua" "$marker_lua"; then pass "hyprland loads kawt"; else fail "hyprland.lua doesn't load kawt"; failed=1; fi
        elif [[ -f $hypr_conf ]]; then
            if loads_kawt "$hypr_conf" "$marker_conf"; then pass "hyprland loads kawt"; else fail "hyprland.conf doesn't load kawt"; failed=1; fi
        fi
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
say "${acc}done.${off} start kawt:  ${acc}qs kill -c kawt-shell; qs -c kawt-shell -d${off}  ${dim}(or log in to hyprland again)${off}"
want zsh && command -v zsh > /dev/null && say "the new prompt shows up in new terminals ${dim}(or now: exec zsh)${off}"
want fastfetch && say "try: ${acc}fastfetch${off}"
if ((!is_arch)); then
    say "${acc}still to get${off} on ${os_name:-this system} (kawt couldn't install them here): $(needs_list)"
    say "${dim}quickshell for your system: https://quickshell.org (install guide); some systems have a package (fedora: copr, nixos)${off}"
fi
say "${dim}first time? super + / shows every key.  ./doctor.sh says what's wrong if something is.${off}"
exit 0
