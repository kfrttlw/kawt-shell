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
#   ./install.sh --update        kawt itself: git pull, then what the new version needs; up to date,
#                                it still makes sure all its packages and their libraries are there.
#                                Right after a git pull by hand (a version from before --update):
#                                what that pull brought, the same way
#                                (also: qs -c kawt-shell ipc call kawt update, or [update] in profile -> cfg)
#   ./install.sh --check         is all of that there? only says (./doctor.sh asks it too)
#   ./install.sh --monitors      your monitors: auto, or each one by hand (mode, position, scale)
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
# ZSH_THEME wherever oh-my-zsh is installed (or without it). No .zshrc yet: it starts as a copy
# of zsh/starter.zshrc (history, tab completion, keys), since bare zsh keeps no history at all
zshrc=${ZDOTDIR:-$HOME}/.zshrc
zsh_starter=$repo/quickshell/kawt-shell/zsh/starter.zshrc
shell_before=$state/shell-before # the login shell kawt switched away from, for --uninstall
marker_zsh="kawt-shell/zsh/kawt.zsh-theme"
line_zsh='[[ -r ~/.config/quickshell/kawt-shell/zsh/kawt.zsh-theme ]] && source ~/.config/quickshell/kawt-shell/zsh/kawt.zsh-theme # kawt prompt'
marker_lua="kawt-shell/hypr/kawt.lua"
marker_conf="kawt-shell/hypr/kawt.conf"
line_lua='pcall(dofile, os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/kawt.lua")'
line_conf='source = ~/.config/quickshell/kawt-shell/hypr/kawt.conf'
hypr_example=/usr/share/hypr/hyprland.lua # Hyprland's own starting config (0.55+)
# kawt's standard config: hyprland.lua becomes three lines loading hypr/preset.lua (kawt's look and
# keys, from the repo: git pull updates it), kawt.lua and ~/.config/hypr/user.lua (yours, last, wins)
hypr_std=$repo/quickshell/kawt-shell/hypr/hyprland.lua
hypr_user_tpl=$repo/quickshell/kawt-shell/hypr/user.lua
hypr_user=$config/hypr/user.lua
marker_std="kawt-shell/hypr/preset.lua"
# nvidia: hyprland's environment for a machine that draws with an nvidia card (hypr/nvidia.lua)
marker_nv_lua="kawt-shell/hypr/nvidia.lua"
marker_nv_conf="kawt-shell/hypr/nvidia.conf"
line_nv_lua='pcall(dofile, os.getenv("HOME") .. "/.config/quickshell/kawt-shell/hypr/nvidia.lua") -- kawt: nvidia'
line_nv_conf='source = ~/.config/quickshell/kawt-shell/hypr/nvidia.conf # kawt: nvidia'
# no login screen: how hyprland starts from the console (both read hypr/login.sh)
#   by itself   right after logging in on tty1: a line in ~/.zprofile (~/.bash_profile)
#   a command   `start`: a line in ~/.zshrc (~/.bashrc)
marker_login="kawt: hyprland at login on tty1"
line_login='[[ -r ~/.config/quickshell/kawt-shell/hypr/login.sh ]] && source ~/.config/quickshell/kawt-shell/hypr/login.sh # kawt: hyprland at login on tty1'
marker_start="kawt: the start command"
line_start="alias start='source ~/.config/quickshell/kawt-shell/hypr/login.sh now' # kawt: the start command"
no_start_ask=$state/no-hyprland-start # "neither" was picked: not asked again
# networkmanager's internet check switched off, if you said so (asked at the install)
nm_quiet=/etc/NetworkManager/conf.d/90-kawt-no-check.conf
marker_nm="kawt: networkmanager's internet check off"
# a desktop's monitors take brightness over DDC/CI (ddcutil), which needs the i2c-dev module
i2c_conf=/etc/modules-load.d/kawt-i2c.conf
marker_i2c="kawt: monitor brightness over DDC/CI"
no_i2c_ask=$state/no-i2c-dev # "no" was answered: not asked again

# the parts, in menu order: id | name | what it is
parts=(
    "shell|shell|the bar, panels, launcher, lock screen, ai (quickshell)"
    "hypr|hyprland|kawt's binds and border colors in your hyprland config"
    "kitty|kitty|the terminal, in the theme's colors"
    "zsh|zsh prompt|┌[user]─[~/dir]─[branch], hints from history, typos marked"
    "fastfetch|fastfetch|short system info with your system's logo"
    "extras|extras|ollama (ai), cava, fortune, wallpapers, night light, power, screenshot tools, qalc, sandbox, voice"
)
# packages per part; "a|b" = the first of them the repos have
pkgs_shell=(quickshell hyprland ttf-jetbrains-mono-nerd papirus-icon-theme libnotify grim slurp wl-clipboard cliphist wf-recorder ffmpeg pipewire wireplumber upower glib2 hyprpicker)
# what a fresh hyprland is missing (arch keeps them optional), with the shell too:
#   pipewire-pulse, -alsa       sound for apps that speak pulseaudio / alsa (browsers, discord...)
#   xdg-desktop-portal-*        screen sharing (hyprland), "open file" windows (gtk)
#   hyprpolkitagent             the password window for apps that need admin rights
#   playerctl                   play / pause / next keys while kawt isn't running
#   noto-fonts-emoji            emoji instead of empty boxes
pkgs_shell+=(pipewire-pulse pipewire-alsa xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent playerctl noto-fonts-emoji)
pkgs_hypr=()
pkgs_kitty=(kitty)
pkgs_zsh=(zsh git zsh-autosuggestions zsh-syntax-highlighting)
pkgs_fastfetch=(fastfetch)
pkgs_extras=(ollama cava fortune-mod "awww|swww" hyprsunset power-profiles-daemon satty tesseract tesseract-data-eng libqalculate wtype bubblewrap whisper-cpp)
# extras for a machine without a backlight (a desktop): the monitors' own brightness
pkgs_desktop=(ddcutil)

mode=install dry=0 yes=0 preset="" packages=1 update=1 updated_from=""
for arg in "$@"; do
    case $arg in
        --update) mode=update ;;
        --check) mode=check ;;
        --monitors) mode=monitors ;;
        --updated=*) updated_from=${arg#*=} ;; # the new install.sh, after --update pulled it (from: the commit before)
        -a | --all) preset=all ;;
        -s | --shell-only) preset=shell ;;
        --no-packages) packages=0 ;;
        --no-update) update=0 ;;
        -y | --yes) yes=1 ;;
        -n | --dry-run) dry=1 ;;
        -u | --uninstall) mode=uninstall ;;
        -h | --help)
            sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'unknown option: %s (see --help)\n' "$arg" >&2
            exit 2
            ;;
    esac
done
# --check goes the way of an update (the parts that are here, no questions) until the packages
# are known, says what it found and stops. --updated=none: --update found nothing new to pull
[[ $mode == check ]] && updated_from=check dry=1 update=0
nothing_new=0
[[ $updated_from == none || $updated_from == check ]] && nothing_new=1

if [[ -t 1 ]]; then
    dim=$'\e[2m' acc=$'\e[1m' red=$'\e[31m' nub=$'\e[38;2;226;35;26m' off=$'\e[0m'
else
    dim='' acc='' red='' nub='' off=''
fi
say() { printf '%s\n' "$*"; }
short() { printf '%s' "${1//"$HOME"/\~}"; } # /home/you/x -> ~/x, for display only
commas() { local IFS=,; printf '%s' "$*" | sed 's/,/, /g'; } # a, b, c
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
    c=$({ stty size < /dev/tty; } 2> /dev/null | cut -d' ' -f2) # braces: no terminal, no message
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

# ask_text <question> <default>: a line typed in, or the default (enter, --yes, nobody to ask)
ask_text() {
    local answer
    if ((yes)) || ! can_ask; then
        printf '%s' "$2"
        return
    fi
    printf '%s %s[%s]%s ' "$1" "$dim" "${2:-none}" "$off" > /dev/tty
    IFS= read -r answer < /dev/tty
    printf '%s' "${answer:-$2}"
}

# ------------------------------------------------------------------ helpers (configs)
loads_kawt() {
    # does <file> load kawt? (a real line, not a commented-out one: -- in lua, # in hyprlang)
    # no `grep -q` after a pipe: it exits early, the writer gets SIGPIPE and pipefail reports a failure
    [[ -f $1 ]] || return 1
    grep -vE '^[[:space:]]*(--|#)' "$1" | grep -F "$2" > /dev/null
}

resolve() { readlink -e -- "$1" 2> /dev/null || true; } # resolved target of a link, empty if broken

# the shell terminals open (from the user database: $SHELL only changes at the next login)
login_shell() { getent passwd "$(id -un)" 2> /dev/null | cut -d: -f7; }
# the file it reads when you log in, and the one for every terminal (zsh and bash; empty for others)
login_profile() {
    case $(login_shell) in
        */zsh) printf '%s' "${ZDOTDIR:-$HOME}/.zprofile" ;;
        */bash) printf '%s' "$HOME/.bash_profile" ;;
    esac
}
login_rc() {
    case $(login_shell) in
        */zsh) printf '%s' "$zshrc" ;;
        */bash) printf '%s' "$HOME/.bashrc" ;;
    esac
}

# the layouts next to us in a hyprland.lua (kb_layout = "us,ru" -> ru), to keep them in a new one
layouts_of() {
    local l x all=() out=()
    l=$(sed -nE 's/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$1" 2> /dev/null | head -n 1)
    IFS=, read -ra all <<< "${l// /}"
    for x in "${all[@]}"; do
        [[ -n $x && $x != us ]] && out+=("$x")
    done
    (IFS=,; printf '%s' "${out[*]}")
}

# set_layouts <file> [layouts]: which keyboard layouts go next to us, into <file>'s
# kb_layout = "us", line (both new configs only know "us"). Offered: [layouts] (the old config's),
# or a guess from the language
set_layouts() {
    local file=$1 suggest=${2:-} lc country layouts l bad="" keep=()
    ((dry)) && { note "would ask for keyboard layouts next to us"; return 0; }
    # a second layout, guessed from the language (ru_RU -> ru)
    lc=${LC_ALL:-${LANG:-}} country=${lc#*_} country=${country%%[.@]*} country=${country,,}
    [[ -z $suggest && $lc == *_* && $country =~ ^[a-z]{2}$ && $country != us && -f /usr/share/X11/xkb/symbols/$country ]] && suggest=$country
    layouts=$(ask_text "keyboard layouts next to us? (like ru or de,ua; - for none)" "${suggest:-}")
    layouts=${layouts// /}
    [[ -z $layouts || $layouts == - ]] && return 0
    for l in ${layouts//,/ }; do
        [[ $l == us ]] && continue
        if [[ $l =~ ^[a-z]{2,3}$ && ( ! -d /usr/share/X11/xkb/symbols || -f /usr/share/X11/xkb/symbols/$l ) ]]; then
            keep+=("$l")
        else
            bad+=" $l"
        fi
    done
    if [[ -n $bad ]]; then
        warn "unknown layout:$bad, keyboard left at us" "later: kb_layout in $file"
        return 0
    fi
    ((${#keep[@]})) || return 0
    layouts=$(IFS=,; printf '%s' "${keep[*]}")
    ((dry)) || sed -i -E "s/^([[:space:]]*kb_layout[[:space:]]*=[[:space:]]*)\"us\",/\1\"us,$layouts\",/; s/^([[:space:]]*kb_options[[:space:]]*=[[:space:]]*)\"\",/\1\"grp:alt_shift_toggle\",/" "$file" || return 1
    step "edit" "keyboard: us,$layouts (alt + shift switches)"
}

# ------------------------------------------------------------------ helpers (monitors)
# Auto: every monitor at its own best mode, side by side (the catch-all rule both new configs
# have). By hand: a rule for each one, in a block of its own in user.lua (hyprland.lua,
# hyprland.conf), which ./install.sh --monitors writes again
mark_mon="kawt monitors ("
mark_mon_end="kawt monitors end"
mon_auto=1
mon_rules=() # name|mode|position|scale|turned; mode "off": that one stays dark

# the monitors connected now, one a line: name|description|modes (its own first). In hyprland,
# hyprctl knows the refresh rates too; from a console, the kernel's /sys/class/drm the sizes only
list_monitors() {
    local out line d n="" desc="" modes=""
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && out=$(hyprctl monitors all 2> /dev/null) && [[ $out == Monitor* ]]; then
        while IFS= read -r line; do
            case $line in
                "Monitor "*)
                    [[ -n $n ]] && printf '%s|%s|%s\n' "$n" "$desc" "$modes"
                    n=${line#Monitor } n=${n%% (ID*} desc="" modes=""
                    ;;
                *"description: "*) desc=${line#*description: } ;;
                *"availableModes: "*) modes=${line#*availableModes: } modes=${modes//Hz/} ;;
            esac
        done <<< "$out"
        [[ -n $n ]] && printf '%s|%s|%s\n' "$n" "$desc" "$modes"
        return 0
    fi
    for d in /sys/class/drm/card*-*; do
        [[ -r $d/status && $(< "$d/status") == connected ]] || continue
        n=${d##*/} n=${n#card*-} # card1-HDMI-A-1 -> HDMI-A-1, the name hyprland gives it
        modes=$(awk '!seen[$0]++' "$d/modes" 2> /dev/null | tr '\n' ' ')
        printf '%s||%s\n' "$n" "$modes"
    done
}

# ask_valid <question> <default> <regex>: asked again until the answer fits
ask_valid() {
    local a
    while :; do
        a=$(ask_text "$1" "$2")
        a=${a// /}
        [[ $a =~ $3 ]] && { printf '%s' "$a"; return 0; }
        printf '    %snot like that:%s %s\n' "$red" "$off" "$a" > /dev/tty
    done
}

# auto, or each monitor by hand: its mode from the ones it has (or typed), where it stands,
# its scale, whether it's turned. Fills mon_auto and mon_rules
monitors_ask() {
    local mons=() line n desc modes all=() m seen mon_c mon_m items on=0 mode pos scale turned
    mon_auto=1 mon_rules=()
    can_ask || return 0
    mapfile -t mons < <(list_monitors)
    section "monitors"
    for line in "${mons[@]}"; do
        IFS='|' read -r n desc _ <<< "$line"
        say "  $n ${dim}$desc${off}"
    done
    say "${dim}  ↑↓ move · enter pick${off}"
    mon_c=0
    choose mon_c "auto|each at its own best mode, side by side: hyprland decides (recommended)" \
        "by hand|mode and refresh rate, position, scale, turning: for each one"
    ((mon_c == 1)) || return 0
    if ((${#mons[@]} == 0)); then
        warn "no monitor found from here, so auto" "later, in hyprland: ./install.sh --monitors"
        return 0
    fi
    mon_auto=0
    for line in "${mons[@]}"; do
        IFS='|' read -r n desc modes <<< "$line"
        say ""
        say "  ${acc}$n${off} ${dim}$desc${off}"
        # the modes it has, each once, its own first (the console knows no refresh rates)
        items=() seen=" "
        read -ra all <<< "$modes"
        for m in "${all[@]}"; do
            [[ $seen == *" $m "* ]] && continue
            seen+="$m "
            if ((${#items[@]} == 0)); then items+=("$m|its own"); else items+=("$m|"); fi
            ((${#items[@]} < 10)) || break
        done
        items+=("highest rate|highrr: the highest refresh rate it has" "type it|like 1920x1080@144" "off|this one stays dark")
        mon_m=0
        choose mon_m "${items[@]}"
        mode=${items[mon_m]%%|*}
        case $mode in
            "highest rate") mode=highrr ;;
            "type it") mode=$(ask_valid "    mode? (1920x1080@144, preferred, highrr, highres)" preferred '^(preferred|highrr|highres|maxwidth|[0-9]+x[0-9]+(@[0-9]+(\.[0-9]+)?)?)$') ;;
            off)
                mon_rules+=("$n|off|||")
                continue
                ;;
        esac
        # the first one on at 0x0, the others to its right
        pos=$(ask_valid "    position? (0x0, 1920x0, auto-right, auto-left, auto-up, auto-down)" "$( ((on)) && echo auto-right || echo 0x0)" '^(auto(-center)?(-(right|left|up|down))?|-?[0-9]+x-?[0-9]+)$')
        scale=$(ask_valid "    scale? (1, 1.25, 1.5, 2, auto)" 1 '^(auto|[0-9]+(\.[0-9]+)?)$')
        turned=$(ask_valid "    turned? (0 no, 1 90°, 2 180°, 3 270°)" 0 '^[0-3]$')
        mon_rules+=("$n|$mode|$pos|$scale|$turned")
        on=$((on + 1))
    done
}

# what was picked, in one line: "DP-1 2560x1440@164.96 at 0x0 x1, HDMI-A-1 off"
monitors_said() {
    local r n mode pos scale turned out=""
    if ((mon_auto)); then
        printf 'auto'
        return 0
    fi
    for r in "${mon_rules[@]}"; do
        IFS='|' read -r n mode pos scale turned <<< "$r"
        [[ -n $out ]] && out+=", "
        if [[ $mode == off ]]; then
            out+="$n off"
        else
            out+="$n $mode at $pos x$scale"
            ((turned)) && out+=" turned $((turned * 90))°"
        fi
    done
    printf '%s' "$out"
}

# the block of rules, for lua (1) or hyprland.conf (0); nothing for auto
monitor_block() {
    local lua=$1 c="#" r n mode pos scale turned
    ((mon_auto)) && return 0
    ((lua)) && c="--"
    printf '%s %s./install.sh --monitors writes these lines again)\n' "$c" "$mark_mon"
    for r in "${mon_rules[@]}"; do
        IFS='|' read -r n mode pos scale turned <<< "$r"
        if ((lua)); then
            if [[ $mode == off ]]; then
                printf 'hl.monitor({ output = "%s", disabled = true })\n' "$n"
            else
                printf 'hl.monitor({ output = "%s", mode = "%s", position = "%s", scale = "%s"%s })\n' "$n" "$mode" "$pos" "$scale" "$( ((turned)) && printf ', transform = %s' "$turned")"
            fi
        elif [[ $mode == off ]]; then
            printf 'monitor = %s, disable\n' "$n"
        else
            printf 'monitor = %s, %s, %s, %s%s\n' "$n" "$mode" "$pos" "$scale" "$( ((turned)) && printf ', transform, %s' "$turned")"
        fi
    done
    printf '%s %s\n' "$c" "$mark_mon_end"
}

# write_monitors <file>: kawt's block in <file> is replaced (auto: taken out). A new one goes
# under user.lua's "-- monitors:" lines, or at the end (last: it wins over rules before it)
write_monitors() {
    local file=$1 lua=0 tmp
    [[ $file == *.lua ]] && lua=1
    if ((mon_auto)) && ! grep -F "$mark_mon" "$file" > /dev/null 2>&1; then
        ((dry)) || step " ok " "$file (monitors: auto)"
        return 0
    fi
    if ((dry)); then
        note "would write the monitors into $file: $(monitors_said)"
        return 0
    fi
    stash_copy "$file" || return 1
    tmp=$file.kawt-tmp
    KAWT_BLOCK=$(monitor_block "$lua") awk -v b="$mark_mon" -v e="$mark_mon_end" '
        BEGIN { blk = ENVIRON["KAWT_BLOCK"] }
        skip { if (index($0, e)) skip = 0; next }
        index($0, b) { skip = 1; if (!done && blk != "") print blk; done = 1; next }
        { print }
        anchor && !done && /^-- hl\.monitor\(/ { if (blk != "") print blk; done = 1 }
        { anchor = /^-- monitors: / }
        END { if (!done && blk != "") printf "\n%s\n", blk }
    ' "$file" > "$tmp" && cat "$tmp" > "$file" && rm -f "$tmp" || { rm -f "$tmp"; return 1; }
    step "edit" "$file (monitors: $(monitors_said))"
}

# Hyprland's own starting config: what it would write itself on the first start (there with an
# "autogenerated" warning on top). Being brand new, it's fitted to kawt: its SUPER + R
# (hyprlauncher) and SUPER + SHIFT + S (a window to the scratchpad) are kawt's run and
# screenshot keys, so those two go out
new_hypr() {
    run mkdir -p "$(dirname "$hypr_lua")" && run cp -- "$hypr_example" "$hypr_lua" || return 1
    ((dry)) || sed -i -E 's/^(hl\.bind\(mainMod \.\. " \+ (R|SHIFT \+ S)",)/-- (kawt uses this key) \1/' "$hypr_lua" || return 1
    step "copy" "$hypr_lua (hyprland's starting config; super+r, super+shift+s left to kawt)"
    set_layouts "$hypr_lua"
    ((mon_auto)) || write_monitors "$hypr_lua"
}

# new_std [layouts] [old config]: kawt's standard config. hyprland.lua becomes its three lines;
# user.lua starts from its template, unless there is one already (it's never replaced), and
# says where the old config went, to take what you miss from it
new_std() {
    local suggest=${1:-} old=${2:-}
    run mkdir -p "$(dirname "$hypr_lua")" && run cp -- "$hypr_std" "$hypr_lua" || return 1
    step "copy" "$hypr_lua (kawt's standard config: preset.lua, kawt.lua, then your user.lua)"
    if [[ -e $hypr_user ]]; then
        step "keep" "$hypr_user (yours)"
    else
        run cp -- "$hypr_user_tpl" "$hypr_user" || return 1
        if [[ -n $old ]] && ((!dry)); then
            sed -i "s|^-- What the standard config does: .*|&\n-- Your config from before kawt's: $(short "$old") (take what you miss from it)|" "$hypr_user" || return 1
        fi
        step "copy" "$hypr_user (yours: monitors, layouts, programs, your own keys)"
        set_layouts "$hypr_user" "$suggest"
    fi
    ((mon_auto)) || write_monitors "$hypr_user"
}

# move <path> into the backup folder, keeping its place relative to $HOME
stash() {
    local path=$1 rel
    rel=${path#"$HOME"/}
    run mkdir -p "$(dirname "$backup/$rel")" || return 1
    run mv -- "$path" "$backup/$rel" || return 1
    step "save" "$path"
    note "-> $backup/$rel"
}

# copy (not move) a file into the backup folder; used before editing it in place.
# One already saved in this run is kept: it's the version from before kawt touched it (a
# second edit, or a new config written over one moved there, would replace it otherwise)
stash_copy() {
    local path=$1 rel
    rel=${path#"$HOME"/}
    [[ -e $backup/$rel ]] && return 0
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

# make <file> load kawt with <line>, unless it already does ([what] it loads, for the message)
hook() {
    local file=$1 marker=$2 line=$3 what=${4:-kawt}
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
        step " ok " "$file loads $what"
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

# ------------------------------------------------------------------ --monitors
# the monitors again, any time: auto, or each one by hand, into kawt's block of user.lua
# (with the standard config; else hyprland.lua or hyprland.conf). Hyprland reads it at once
if [[ $mode == monitors ]]; then
    banner "monitors"
    ((dry)) && say "${dim}dry run: nothing will be changed${off}"
    if loads_kawt "$hypr_lua" "$marker_std" && [[ -f $hypr_user ]]; then
        mon_file=$hypr_user
    elif [[ -f $hypr_lua ]]; then
        mon_file=$hypr_lua
    elif [[ -f $hypr_conf ]]; then
        mon_file=$hypr_conf
    else
        say "${red}no hyprland config yet${off}: ./install.sh first"
        exit 1
    fi
    if ! can_ask; then
        say "${red}this one asks you things${off}: run it in a terminal, without --yes"
        exit 1
    fi
    monitors_ask
    section "write"
    write_monitors "$mon_file" || { fail "could not write $mon_file"; exit 1; }
    if ((!dry)) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl reload > /dev/null 2>&1; then
        pass "hyprland read it again"
    fi
    [[ -d $backup ]] && say "${dim}the file before: $(short "$backup")${off}"
    exit 0
fi

# ------------------------------------------------------------------ update
# --update: kawt itself, from git. The configs are links into this folder, so a pull is most of
# it; then the new install.sh takes over (--updated) for what the new version needs: new
# packages and links for the parts already here, the shell and hyprland loaded again. Yours is
# never touched: settings, ~/.config/kawt/themes.json, ~/.config/hypr/user.lua all live outside
# the repo. Changes made inside the repo stop it (a pull would mix them in): they're listed,
# and git stash can put them aside first. The only time kawt asks the internet for its own
# updates is this, and [check] in profile -> cfg, when you press it.
if [[ $mode == update ]]; then
    if ((EUID == 0)); then
        say "${red}run this as your own user, not as root${off} ${dim}(git would leave root's files in your clone)${off}"
        exit 1
    fi
    banner "update"
    ((dry)) && say "${dim}dry run: nothing will be changed${off}"
    say ""
    g() { GIT_TERMINAL_PROMPT=0 git -C "$repo" "$@"; } # never stops to ask for a password
    if ! g rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        say "${red}$(short "$repo") isn't a git clone${off}, so kawt can't update itself here"
        note "with git: git clone https://github.com/kfrttlw/kawt-shell ~/kawt && ~/kawt/install.sh"
        exit 1
    fi
    if ! up=$(g rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2> /dev/null); then
        say "${red}the branch $(g branch --show-current) follows no branch of the remote${off}"
        note "to follow main: git -C $repo branch -u origin/main"
        exit 1
    fi
    changed=$(g status --porcelain --untracked-files=no)
    if [[ -n $changed ]]; then
        say "files of the repo were changed here:"
        printf '%s\n' "$changed" | sed 's/^.../  /'
        note "your own colors, look and keys go outside it: ~/.config/kawt/themes.json, profile -> cfg, ~/.config/hypr/user.lua"
        if ((!dry && !yes)) && can_ask && ask "put them aside (git stash) and update? git stash pop brings them back" 1; then
            g stash push -q -m "kawt: before the update of $stamp" || { fail "git stash failed"; exit 1; }
            step "save" "your changes (back with: git -C $repo stash pop)"
        else
            say "${dim}nothing was changed.${off}"
            exit 1
        fi
    fi
    # for the new installer, which does the rest: it may know more than this one
    fwd=()
    ((yes)) && fwd+=(--yes)
    ((packages)) || fwd+=(--no-packages)
    ((update)) || fwd+=(--no-update)
    step "ask" "$up for news"
    g fetch -q || { fail "git fetch failed" "no internet, or the remote isn't there any more"; exit 1; }
    old=$(g rev-parse HEAD)
    behind=$(g rev-list --count 'HEAD..@{u}')
    ahead=$(g rev-list --count '@{u}..HEAD')
    if ((behind == 0)); then
        # pulled by hand a moment ago (the first update from a version that had no --update,
        # or a plain git pull): what's new since then, as if this had pulled it. Once per pull
        read -r ref how _ <<< "$(g reflog -1 --date=unix --format='%gd %gs' 2> /dev/null)"
        when=${ref#*\{}
        when=${when%\}}
        prev=$(g rev-parse -q --verify 'HEAD@{1}' 2> /dev/null)
        seen=$state/pull-seen
        if [[ $how == pull* && $when =~ ^[0-9]+$ ]] && (($(date +%s) - when < 6 * 3600)) &&
            [[ -n $prev && $prev != "$old" && $(cat "$seen" 2> /dev/null) != "$ref" ]] &&
            g merge-base --is-ancestor "$prev" HEAD 2> /dev/null; then
            pass "pulled by hand: $(g rev-list --count "$prev..HEAD") new since $(g log -1 --format='%h' "$prev")"
            if ((dry)); then
                fwd+=(--dry-run)
            else
                mkdir -p "$state" && printf '%s\n' "$ref" > "$seen"
            fi
            exec "$repo/install.sh" --updated="$prev" "${fwd[@]}"
        fi
        pass "kawt is up to date ($(g log -1 --format='%h, %cr'))"
        # still: is all it needs there? (a package removed since, one an older install missed,
        # a library gone after a system update)
        ((dry)) && fwd+=(--dry-run)
        exec "$repo/install.sh" --updated=none "${fwd[@]}"
    fi
    if ((ahead > 0)); then
        fail "this clone has $ahead commit(s) of its own that $up doesn't" "merge them by hand: git -C $repo pull"
        exit 1
    fi
    section "new: $behind"
    g log --no-merges --format='  %s' 'HEAD..@{u}' | head -n 15 | cut -c1-"$(cols)"
    ((behind > 15)) && note "... and $((behind - 15)) more: git -C $repo log"
    say ""
    if ! ask "update?"; then
        say "${dim}nothing was changed.${off}"
        exit 0
    fi
    if ((dry)); then
        note "would run: git merge --ff-only $up, then the new install.sh for the rest"
        exit 0
    fi
    g merge -q --ff-only '@{u}' || { fail "git merge failed" "see above"; exit 1; }
    pass "kawt is at $(g log -1 --format='%h')"
    exec "$repo/install.sh" --updated="$old" "${fwd[@]}"
fi

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
    # kawt made zsh the login shell: offer the old one back (zsh itself stays installed)
    if [[ -f $shell_before ]]; then
        old=$(< "$shell_before")
        if [[ -n $old && $(login_shell) == */zsh && $old != */zsh ]] && ((!dry)) && ask "your shell was ${old##*/} before kawt: switch back to it?" 1; then
            chsh -s "$old" && step "edit" "your shell: zsh -> ${old##*/} (everywhere after logging in again)" || warn "could not switch the shell back" "by hand: chsh -s $old"
        fi
        ((dry)) || rm -f -- "$shell_before"
    fi

    for f in "${ZDOTDIR:-$HOME}/.zprofile" "$HOME/.bash_profile"; do
        if [[ -f $f ]] && grep -F "$marker_login" "$f" > /dev/null; then
            stash_copy "$f" && run sed -i "\|$marker_login|d" "$f" && step "edit" "$f (hyprland at login removed)"
        fi
    done
    for f in "$zshrc" "$HOME/.bashrc"; do
        if [[ -f $f ]] && grep -F "$marker_start" "$f" > /dev/null; then
            stash_copy "$f" && run sed -i "\|$marker_start|d" "$f" && step "edit" "$f (the start command removed)"
        fi
    done
    ((dry)) || rm -f -- "$no_start_ask"
    # networkmanager's internet check, switched off by kawt: on again
    ((dry)) || rm -f -- "$no_i2c_ask"
    if [[ -f $i2c_conf ]] && grep -F "$marker_i2c" "$i2c_conf" > /dev/null && ask "kawt loads i2c-dev at boot (monitor brightness): stop that?"; then
        run sudo rm -f -- "$i2c_conf" && step "rm" "$i2c_conf"
    fi
    if [[ -f $nm_quiet ]] && grep -F "$marker_nm" "$nm_quiet" > /dev/null && ask "networkmanager's internet check was switched off by kawt: on again?"; then
        run sudo rm -f -- "$nm_quiet" && run sudo systemctl reload NetworkManager && step "rm" "$nm_quiet (the internet check is on again)"
    fi

    # hyprland.lua loads kawt's standard config, from the kawt folder that's going away. The one
    # from before is in the oldest backup: back it comes. With none (or a no), the standard
    # config is copied into hyprland.lua, so it works without kawt; user.lua stays loaded
    if [[ -f $hypr_lua ]] && loads_kawt "$hypr_lua" "$marker_std"; then
        if orig=$(original "${hypr_lua#"$HOME"/}") && ! loads_kawt "$orig" "$marker_std" && ask "put your hyprland.lua from before kawt back?"; then
            stash_copy "$hypr_lua" && run cp -a -- "$orig" "$hypr_lua" && step "back" "$hypr_lua"
        else
            stash_copy "$hypr_lua"
            if ((!dry)); then
                {
                    printf -- '-- kawt was uninstalled: its standard config (hypr/preset.lua), copied in. Yours to edit.\n\n'
                    cat -- "$repo/quickshell/kawt-shell/hypr/preset.lua"
                    printf '\ndofile(os.getenv("HOME") .. "/.config/hypr/user.lua")\n'
                } > "$hypr_lua"
            fi
            step "edit" "$hypr_lua (the standard config copied in: it works without kawt)"
        fi
    fi
    for f in "$hypr_lua" "$hypr_conf"; do
        [[ -f $f ]] || continue
        if grep -F -e "$marker_lua" -e "$marker_conf" -e "$marker_nv_lua" -e "$marker_nv_conf" "$f" > /dev/null; then
            stash_copy "$f" && run sed -i -e "\|$marker_lua|d" -e "\|$marker_conf|d" -e "\|$marker_nv_lua|d" -e "\|$marker_nv_conf|d" "$f" && step "edit" "$f (kawt lines removed)"
        fi
    done
    say ""
    say "done. ${dim}packages stay installed; settings and notes in $(short "$state") were kept.${off}"
    exit 0
fi

# ------------------------------------------------------------------ 0. who and where
# after --update this is the new installer, for the parts that are here already: no menus,
# no questions answered at the install (services, the login shell, hyprland's start)
if [[ -n $updated_from ]]; then
    preset=update
    if ((nothing_new)); then section "what kawt needs here"; else section "what the new version needs"; fi
else
    banner "installer"
fi
((dry)) && [[ $mode != check ]] && say "${dim}dry run: nothing will be changed${off}"
# --check speaks like doctor.sh, which shows what it says
if [[ $mode == check ]]; then
    pass() { step " ok " "$1"; }
    fail() {
        step " !! " "${red}$1${off}"
        [[ -n ${2:-} ]] && note "$2"
        errors=$((errors + 1))
        return 0
    }
fi

if ((EUID == 0)); then
    say ""
    say "${red}run this as your own user, not as root${off} ${dim}(it asks for sudo itself, only for pacman)${off}"
    exit 1
fi

for f in quickshell/kawt-shell/shell.qml quickshell/kawt-shell/hypr/kawt.lua quickshell/kawt-shell/hypr/kawt.conf quickshell/kawt-shell/hypr/preset.lua quickshell/kawt-shell/hypr/hyprland.lua quickshell/kawt-shell/hypr/user.lua quickshell/kawt-shell/hypr/nvidia.lua quickshell/kawt-shell/hypr/nvidia.conf kitty/kitty.conf fastfetch/config.jsonc quickshell/kawt-shell/zsh/kawt.zsh-theme quickshell/kawt-shell/zsh/starter.zshrc; do
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
    # the parts kawt finds here (the extras can't be told apart from anything else: ./install.sh adds them)
    update)
        on=(0 0 0 0 0 0)
        [[ -L $qs_dst && $(resolve "$qs_dst") == "$(resolve "$repo/quickshell/kawt-shell")" ]] && on[0]=1
        { loads_kawt "$hypr_lua" "$marker_lua" || loads_kawt "$hypr_conf" "$marker_conf"; } && on[1]=1
        [[ -L $kitty_dst && $(resolve "$kitty_dst") == "$(resolve "$repo/kitty/kitty.conf")" ]] && on[2]=1
        loads_kawt "$zshrc" "$marker_zsh" && on[3]=1
        [[ -L $fastfetch_dst && $(resolve "$fastfetch_dst") == "$(resolve "$fastfetch_src")" ]] && on[4]=1
        ;;
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

installed() { pacman -T -- "$1" > /dev/null 2>&1; } # also true for a package that provides it (quickshell-git)
in_repos() { pacman -Si -- "$1" > /dev/null 2>&1; }

# wallpapers: awww draws them, with transitions, and kawt starts its daemon itself (no line in
# hyprland's config). It comes with the extras; with the shell alone it's asked on its own
wall_awww=0
if want shell && ! want extras && ((packages)) && [[ -z $updated_from ]] && ! installed awww && ! installed swww; then
    ask "wallpapers through awww? (smooth transitions; kawt starts it with hyprland)" 1 && wall_awww=1
fi

# ------------------------------------------------------------------ 2b. hyprland's config
# What hyprland.lua becomes (hypr_from):
#   ""     left as it is, kawt only adds its line at the end
#   std    kawt's standard config (hypr/preset.lua: kawt's animations, floating windows, keys,
#          updated with kawt) + ~/.config/hypr/user.lua for your own; one that's there goes to
#          the backup. With no config yet, the default
#   hypr   Hyprland's own starting config
# Not for the classic hyprland.conf: the standard config is lua, and hyprland would read both
hypr_from=""
if want hypr && [[ ! -f $hypr_conf && -z $updated_from ]]; then
    if [[ ! -f $hypr_lua ]]; then
        hypr_from=std
        if can_ask; then
            section "hyprland config"
            say "${dim}  there is none yet · ↑↓ move · enter pick${off}"
            c=0
            choose c "kawt standard|crt animations, floating tools, super+v, window mode; yours in user.lua (recommended)" \
                "hyprland's own|the starting config hyprland ships, kawt's keys added"
            ((c == 1)) && hypr_from=hypr
        fi
    elif ! loads_kawt "$hypr_lua" "$marker_std" && can_ask; then
        section "hyprland config"
        say "${dim}  you have one · ↑↓ move · enter pick${off}"
        c=0
        choose c "keep mine|kawt only adds its line at the end (recommended)" \
            "kawt standard|kawt's config, updated with kawt; yours to the backup, changes in user.lua"
        ((c == 1)) && hypr_from=std
    fi
fi

# a new config: the monitors, auto or each one by hand (again any time: ./install.sh --monitors)
[[ $hypr_from == std || $hypr_from == hypr ]] && monitors_ask

# ------------------------------------------------------------------ 2c. nvidia
# An nvidia card (from /sys: no lspci needed) gets two offers:
#   hyprland env   hypr/nvidia.lua: video decoding on the gpu, OpenGL through nvidia. Only when
#                  nvidia draws alone: on a hybrid laptop the intel / amd gpu draws
#   driver         when none is installed. Which one goes by the card's pci id:
#                    >= 0x1e00   Turing and newer (GTX 16xx, RTX): nvidia-open-dkms, from the repos
#                    >= 0x1340   Maxwell, Pascal (GTX 9xx, 10xx): the 590 drivers dropped them,
#                                nvidia-580xx-dkms from the aur (with paru / yay: a split package)
#                    older       the 470xx and older: by hand (the arch wiki's NVIDIA page)
#                  dkms builds the module for every kernel there is (linux, lts, zen...), so their
#                  headers come along; lib32 for steam when multilib is on; nvidia-prime (prime-run)
#                  on a hybrid. modeset and fbdev the driver turns on itself.
nv_dev="" nv_slot="" nv_other=0 nv_cfg=0 nv_driver=0 nv_pkgs=()
for d in /sys/bus/pci/devices/*; do
    [[ -r $d/class && $(< "$d/class") == 0x03* ]] || continue # 0x03: display controllers
    if [[ $(< "$d/vendor") == 0x10de ]]; then
        nv_dev=$(< "$d/device") nv_slot=${d##*/}
    else
        nv_other=1
    fi
done
if [[ -n $nv_dev && -z $updated_from ]] && { want hypr || ((packages)); }; then
    nv_name=$(lspci -s "$nv_slot" 2> /dev/null | sed -E 's/^[^:]*:[^:]*: //; s/ \(rev [0-9a-f]+\)$//')
    if ((nv_dev >= 0x1e00)); then
        nv_gen=open
    elif ((nv_dev >= 0x1340)); then
        nv_gen=580xx
    else
        nv_gen=old
    fi
    nv_have=""
    if command -v pacman > /dev/null; then
        for p in nvidia-utils nvidia-580xx-utils nvidia-470xx-utils nvidia-390xx-utils; do
            installed "$p" && { nv_have=$p; break; }
        done
    fi
    [[ -z $nv_have && -e /proc/driver/nvidia/version ]] && nv_have="loaded"
    lib32=0
    grep -E '^[[:space:]]*\[multilib\]' /etc/pacman.conf > /dev/null 2>&1 && lib32=1
    headers=()
    for f in /usr/lib/modules/*/pkgbase; do
        [[ -r $f ]] && headers+=("$(< "$f")-headers")
    done
    ((${#headers[@]})) || headers=(linux-headers) # no kernel found: arch's own
    helper=$(command -v paru || command -v yay || true)

    items=() keys=() notes=()
    if want hypr && ((!nv_other)); then
        items+=("hyprland env|video decoding on the gpu, OpenGL through nvidia (hypr/nvidia.lua)") keys+=(cfg)
    elif want hypr; then
        notes+=("hybrid: hyprland draws on the intel / amd gpu, it needs no nvidia settings")
    fi
    if [[ -n $nv_have ]]; then
        notes+=("driver: there already ($nv_have)")
    elif ((!packages)); then
        notes+=("driver: none yet; kawt doesn't install packages here (see the arch wiki's NVIDIA page)")
    elif [[ $nv_gen == open ]]; then
        nv_pkgs=(nvidia-open-dkms nvidia-utils libva-nvidia-driver "${headers[@]}")
        ((lib32)) && nv_pkgs+=(lib32-nvidia-utils)
        items+=("driver|nvidia-open-dkms, nvidia-utils, video decoding, kernel headers (a reboot after)") keys+=(driver)
    elif [[ $nv_gen == 580xx && -n $helper ]]; then
        nv_pkgs=(nvidia-580xx-dkms nvidia-580xx-utils libva-nvidia-driver "${headers[@]}")
        ((lib32)) && nv_pkgs+=(lib32-nvidia-580xx-utils)
        items+=("driver|nvidia-580xx-dkms from the aur, the last one for gtx 9xx / 10xx (a reboot after)") keys+=(driver)
    elif [[ $nv_gen == 580xx ]]; then
        notes+=("driver: gtx 9xx / 10xx need nvidia-580xx-dkms from the aur; with paru or yay installed, ./install.sh offers it")
    else
        notes+=("driver: this card is older than the current drivers; see the arch wiki's NVIDIA page")
    fi
    ((${#nv_pkgs[@]})) && ((nv_other)) && nv_pkgs+=(nvidia-prime)

    nvo=()
    for k in "${keys[@]}"; do
        # asked: both on, untick what you don't want. not asked: --yes takes both, otherwise only the env
        if can_ask; then nvo+=(1); elif [[ $k == cfg ]] || ((yes)); then nvo+=(1); else nvo+=(0); fi
    done
    if can_ask; then
        section "nvidia"
        say "  ${nv_name:-an nvidia card}$( ((nv_other)) && printf ' %s(+ intel / amd graphics: a hybrid)%s' "$dim" "$off")"
        for n in "${notes[@]}"; do note "$n"; done
        if ((${#items[@]})); then
            say "${dim}  ↑↓ move · space on/off · enter go on${off}"
            pick nvo "${items[@]}"
        fi
    fi
    for i in "${!keys[@]}"; do
        ((nvo[i])) || continue
        [[ ${keys[i]} == cfg ]] && nv_cfg=1
        [[ ${keys[i]} == driver ]] && nv_driver=1
    done
fi

# ------------------------------------------------------------------ 3. packages

# what the picked parts need (arch package names; "a|b" = the first one there is)
wanted=()
for id in shell hypr kitty zsh fastfetch extras; do
    want "$id" || continue
    declare -n list="pkgs_$id"
    wanted+=("${list[@]}")
    unset -n list
done
want shell && compgen -G "/sys/class/backlight/*" > /dev/null && wanted+=(brightnessctl)
((wall_awww)) && wanted+=("awww|swww")
# [text] on a screenshot reads english, and your language when tesseract knows it (ru_RU -> rus)
tess_lang() {
    case ${LC_ALL:-${LANG:-}} in
        ru_*) echo tesseract-data-rus ;;
        uk_*) echo tesseract-data-ukr ;;
        de_*) echo tesseract-data-deu ;;
        fr_*) echo tesseract-data-fra ;;
        es_*) echo tesseract-data-spa ;;
        pl_*) echo tesseract-data-pol ;;
    esac
}
if want extras; then
    t=$(tess_lang)
    [[ -n $t ]] && wanted+=("$t")
fi
# the extras that make sense here
extras_here=("${pkgs_extras[@]}")
compgen -G "/sys/class/backlight/*" > /dev/null || extras_here+=("${pkgs_desktop[@]}")
want extras && ! compgen -G "/sys/class/backlight/*" > /dev/null && wanted+=("${pkgs_desktop[@]}")
have_any() { # have_any "a|b": one of them is installed
    local p alts
    IFS='|' read -ra alts <<< "$1"
    for p in "${alts[@]}"; do installed "$p" && return 0; done
    return 1
}
# what an extra is for, when it's offered on its own
about() {
    case $1 in
        ollama) echo "the ai panel's local models" ;;
        cava) echo "real sound bars at the player" ;;
        fortune-mod) echo "a new motto every time (profile)" ;;
        "awww|swww") echo "wallpapers with transitions" ;;
        hyprsunset) echo "night light" ;;
        power-profiles-daemon) echo "power profiles in the battery panel" ;;
        satty) echo "[edit] on screenshots" ;;
        tesseract | tesseract-data-*) echo "[text] on screenshots" ;;
        libqalculate) echo "= in the launcher: units, currencies, dates" ;;
        wtype) echo "emoji from the launcher typed in, not only copied" ;;
        bubblewrap) echo "the coder runs commands you approve in a sandbox (no network, only the project)" ;;
        whisper-cpp) echo "speak to the ai panel (super + alt + v), written down on this machine" ;;
        ddcutil) echo "the monitors' own brightness, from the bar (no backlight here)" ;;
        *) echo "" ;;
    esac
}
# After an update: optional packages new in this version. Which extras you took can't be told
# from what's installed (cava may be there for its own sake), so only those the version you came
# from didn't have yet are offered; the rest stays as you left it
new_extras=()
if [[ -n $updated_from ]] && ((!nothing_new && packages)) && ! want extras; then
    old=$(git -C "$repo" show "$updated_from:install.sh" 2> /dev/null | sed -n 's/^pkgs_\(extras\|desktop\)=(\(.*\))$/\2/p' | tr '\n' ' ')
    if [[ -n $old ]]; then
        read -ra old_extras <<< "${old//\"/}"
        for spec in "${extras_here[@]}"; do
            [[ " ${old_extras[*]} " == *" $spec "* ]] || have_any "$spec" || new_extras+=("$spec")
        done
    fi
fi
if ((${#new_extras[@]})); then
    say "  optional ones new in this version:"
    for spec in "${new_extras[@]}"; do
        printf '    %-22s %s%s%s\n' "${spec//|/ or }" "$dim" "$(about "$spec")" "$off"
    done
    if ask "  install them too?" 1; then
        wanted+=("${new_extras[@]}")
        t=$(tess_lang)
        [[ " ${new_extras[*]} " == *" tesseract "* && -n $t ]] && wanted+=("$t")
    elif ! can_ask; then
        note "nobody to ask here; to add them: sudo pacman -S --needed ${new_extras[*]%%|*}"
    fi
fi
want shell && compgen -G "/sys/class/bluetooth/*" > /dev/null && wanted+=(bluez bluez-utils)
((nv_driver)) && wanted+=("${nv_pkgs[@]}")

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
        # still on pulseaudio itself: pipewire-pulse / -alsa would replace it, leave that be
        [[ ${alts[0]} == pipewire-pulse || ${alts[0]} == pipewire-alsa ]] && installed pulseaudio && continue
        # another password window (polkit agent) is already there: one is enough
        if [[ ${alts[0]} == hyprpolkitagent ]]; then
            for a in polkit-gnome polkit-kde-agent lxqt-policykit mate-polkit; do installed "$a" && continue 2; done
        fi
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
# an update of kawt with nothing new to install doesn't update the whole system on the side
[[ -n $updated_from ]] && ((${#repo_pkgs[@]} == 0)) && update=0

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
        hyprpolkitagent) echo "a polkit agent (hyprpolkitagent)" ;;
        noto-fonts-emoji) echo "an emoji font (Noto Color Emoji)" ;;
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
if ((packages)) && [[ $mode != check ]] && pacman -Qmq 2> /dev/null | grep -x quickshell > /dev/null; then
    qs_have=$(pacman -Q quickshell 2> /dev/null | cut -d' ' -f2)
    v=$(aur_version quickshell)
    [[ -n $v && -n $qs_have ]] && (($(vercmp "$v" "$qs_have") > 0)) && qs_update=$v
fi
# quickshell already behind the installed Qt (see stale_quickshell)
stale_now=""
((packages)) && stale_now=$(stale_quickshell)
# Can kawt's programs load their libraries? pacman -Dk lists the installed packages whose
# dependencies are gone (a library removed by hand, an update left half done, pacman -Rdd); the
# ones kawt uses count here. ldd finds the .so files quickshell itself can't open: an aur build
# whose library went away or changed under it.
libs_missing=() libs_for=() qs_libs=()
check_libs() {
    local line p names=" " re="missing '([^']+)' dependency for '([^']+)'"
    libs_missing=() libs_for=() qs_libs=()
    for p in "${wanted[@]}"; do names+="${p//|/ } "; done
    while IFS= read -r line; do
        [[ $line =~ $re ]] || continue
        p=${BASH_REMATCH[2]}
        [[ $names == *" $p "* || $names == *" ${p%-git} "* || $names == *" ${p%-bin} "* ]] || continue
        [[ " ${libs_missing[*]} " == *" ${BASH_REMATCH[1]} "* ]] || libs_missing+=("${BASH_REMATCH[1]}")
        [[ " ${libs_for[*]} " == *" $p "* ]] || libs_for+=("$p")
    done < <(LC_ALL=C pacman -Dk 2>&1)
    if command -v qs > /dev/null && command -v ldd > /dev/null; then
        mapfile -t qs_libs < <(LC_ALL=C ldd "$(command -v qs)" 2> /dev/null | awk '/not found/ {print $1}' | sort -u)
    fi
}

# without paru / yay an aur quickshell is (re)built here: that needs git and base-devel
if [[ -z $aur_helper ]] && { ((${#aur_pkgs[@]})) || [[ -n $qs_have ]]; }; then
    for p in git base-devel; do
        installed "$p" || [[ " ${repo_pkgs[*]} " == *" $p "* ]] || repo_pkgs+=("$p")
    done
fi

# ------------------------------------------------------------------ --check: what it found
if [[ $mode == check ]]; then
    names=()
    for i in "${!parts[@]}"; do
        ((on[i])) && { p=${parts[i]#*|}; names+=("${p%%|*}"); }
    done
    if ((${#names[@]} == 0)); then
        fail "kawt isn't installed here (none of its links)" "./install.sh"
        exit 1
    fi
    if ((!is_arch || !packages)); then
        note "${os_name:-this system}: kawt can't tell its packages here (not arch)"
        exit 0
    fi
    missing=("${repo_pkgs[@]}" "${aur_pkgs[@]}")
    if ((${#missing[@]})); then
        fail "missing for $(commas "${names[@]}"): $(commas "${missing[@]}")" "./install.sh --update installs them"
    else
        pass "packages for $(commas "${names[@]}"): all $have there"
    fi
    opt=()
    for spec in "${extras_here[@]}"; do have_any "$spec" || opt+=("${spec//|/ or }"); done
    ((${#opt[@]})) && note "optional, not installed: $(commas "${opt[@]}")"
    check_libs
    ((${#libs_missing[@]})) && fail "not installed, though $(commas "${libs_for[@]}") need$( ((${#libs_for[@]} == 1)) && printf s) it: $(commas "${libs_missing[@]}")" "./install.sh --update installs it (or: sudo pacman -S --asdeps ${libs_missing[*]})"
    ((${#qs_libs[@]})) && fail "quickshell can't load ${qs_libs[*]}" "./install.sh --update builds it again (aur), or sudo pacman -Syu"
    ((${#libs_missing[@]} + ${#qs_libs[@]})) || pass "libraries: none missing"
    exit $((errors > 0))
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
printf '  %-9s %s\n' "$([[ -n $updated_from ]] && printf 'check' || printf 'install')" "$(IFS=,; printf '%s' "${names[*]}" | sed 's/,/, /g')"
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
case $hypr_from in
    std) printf '  %-9s %s\n' "hyprland" "kawt's standard config + user.lua for yours$( [[ -f $hypr_lua ]] && printf ' %s(your hyprland.lua goes to the backup)%s' "$dim" "$off")" ;;
    hypr) printf '  %-9s %s\n' "hyprland" "hyprland's own starting config" ;;
esac
((mon_auto)) || printf '  %-9s %s\n' "monitors" "$(monitors_said)"
if ((nv_cfg || nv_driver)); then
    printf '  %-9s %s\n' "nvidia" "$( ((nv_cfg)) && printf 'hyprland env')$( ((nv_cfg && nv_driver)) && printf ' + ')$( ((nv_driver)) && printf 'the driver %s(a reboot after)%s' "$dim" "$off")"
fi
printf '  %-9s %s\n' "then" "link the configs ${dim}(what's there now goes to $(short "$backup"))${off}"
say ""
# after an update with nothing to install, there's nothing to ask: the links are checked only
quiet_update=0
[[ -n $updated_from ]] && ((${#repo_pkgs[@]} == 0 && ${#aur_pkgs[@]} == 0)) && [[ -z $qs_update && -z $stale_now ]] && quiet_update=1
if ((!quiet_update)) && ! ask "go?"; then
    say "${dim}nothing was changed.${off}"
    exit 0
fi

# ------------------------------------------------------------------ 5. install packages
failed=0
touched=0 # packages were installed or built: after an update with nothing new the shell restarts for them
((!dry)) && { ((${#repo_pkgs[@]} + ${#aur_pkgs[@]})) || [[ -n $qs_update || -n $stale_now ]]; } && touched=1
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

    # their libraries (see check_libs): what's missing is installed, an aur quickshell that
    # can't load its own is built again
    check_libs
    ((${#libs_missing[@]} + ${#qs_libs[@]})) || pass "libraries: none missing"
    if ((${#libs_missing[@]})); then
        warn "not installed, though $(commas "${libs_for[@]}") need$( ((${#libs_for[@]} == 1)) && printf s) it: $(commas "${libs_missing[@]}")" "a library removed, or an update left half done"
        if ask "install it?" 1; then
            if run sudo pacman -S --needed --asdeps "${noconfirm[@]}" "${libs_missing[@]}"; then
                ((dry)) || touched=1
            else
                fail "pacman failed" "see above"
                failed=1
            fi
        fi
    fi
    if ((${#qs_libs[@]})); then
        q=$(pacman -Qq 2> /dev/null | grep -xE 'quickshell(-git)?' | head -n 1)
        if [[ -n $q ]] && pacman -Qmq 2> /dev/null | grep -x "$q" > /dev/null; then
            note "$q can't load ${qs_libs[*]}: building it again against what's here"
            if [[ -n $aur_helper ]]; then
                run "$aur_helper" -S --rebuild "${noconfirm[@]}" "$q" || { fail "rebuilding $q failed" "see above"; failed=1; }
            else
                aur_build "$q" rebuild || { fail "rebuilding $q failed" "see above"; failed=1; }
            fi
            ((failed || dry)) || touched=1
        else
            fail "${q:-quickshell} can't load ${qs_libs[*]}" "an update left half done: sudo pacman -Syu"
            failed=1
        fi
    fi
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
if [[ -f $hypr_lua && $hypr_from != std ]]; then
    if grep -vE '^[[:space:]]*--' "$hypr_lua" | grep -E 'require[[:space:]]*\(?[[:space:]]*["'"'"']kawt' > /dev/null; then
        fail "hyprland.lua has an old require(\"kawt\") line" "delete it: the file it loads is gone and it breaks the config"
    fi
    # if a lua compiler is around, make sure the config parses *before* we touch it
    luac=$(command -v luac || command -v luac5.4 || command -v luac5.3 || true)
    if [[ -n $luac ]] && ! "$luac" -p -- "$hypr_lua" > /dev/null 2>&1; then
        fail "hyprland.lua already has a syntax error" "see: $luac -p $hypr_lua"
    fi
elif want hypr && [[ $hypr_from != std && ! -f $hypr_conf && ! -f $hypr_example ]] && ! ((dry && packages)); then
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
# where the style window (super + w) looks for wallpapers
if want shell && [[ ! -d $HOME/Pictures/wallpapers ]]; then
    run mkdir -p "$HOME/Pictures/wallpapers" && step "make" "$HOME/Pictures/wallpapers (put wallpapers here: super + w picks them)"
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
    if [[ $hypr_from == std && -f $hypr_lua ]]; then
        old_layouts=$(layouts_of "$hypr_lua")
        { stash "$hypr_lua" && new_std "$old_layouts" "$backup/${hypr_lua#"$HOME"/}"; } || { fail "could not set up $hypr_lua"; failed=1; }
    elif [[ ! -f $hypr_lua && ! -f $hypr_conf ]]; then
        # hyprland's own needs hyprland 0.55+ installed (it ships that file); the standard config is in the repo
        if [[ $hypr_from == std ]]; then
            new_std || { fail "could not set up $hypr_lua"; failed=1; }
        elif [[ -f $hypr_example ]] || ((dry && packages)); then
            new_hypr || { fail "could not set up $hypr_lua"; failed=1; }
        fi
    fi
    if [[ -f $hypr_lua ]]; then
        hook "$hypr_lua" "$marker_lua" "$line_lua" || { fail "could not edit $hypr_lua"; failed=1; }
        ((nv_cfg)) && { hook "$hypr_lua" "$marker_nv_lua" "$line_nv_lua" "kawt's nvidia settings" || { fail "could not edit $hypr_lua"; failed=1; }; }
    elif [[ -f $hypr_conf ]]; then
        hook "$hypr_conf" "$marker_conf" "$line_conf" || { fail "could not edit $hypr_conf"; failed=1; }
        ((nv_cfg)) && { hook "$hypr_conf" "$marker_nv_conf" "$line_nv_conf" "kawt's nvidia settings" || { fail "could not edit $hypr_conf"; failed=1; }; }
    fi
fi
if want zsh && command -v zsh > /dev/null; then
    undo_old_zsh_setup
    if [[ ! -e $zshrc ]]; then
        run mkdir -p "$(dirname "$zshrc")" && run cp -- "$zsh_starter" "$zshrc" && step "copy" "$zshrc (kawt's starter: history, tab completion, keys)"
    fi
    hook "$zshrc" "$marker_zsh" "$line_zsh" || { fail "could not edit $zshrc"; failed=1; }
fi

# ------------------------------------------------------------------ 8. services
# only asked, never just switched on (and not again after an update: that was answered)
if ((!dry)) && [[ -z $updated_from ]]; then
    # the prompt lives in zsh: if terminals open bash, nobody sees it
    if want zsh && zsh_path=$(command -v zsh) && old=$(login_shell) && [[ -n $old && $old != */zsh ]]; then
        if ask "terminals open ${old##*/}, the prompt is in zsh: make zsh your shell? (chsh asks your password)" 1; then
            if chsh -s "$zsh_path"; then
                mkdir -p "$state" && printf '%s\n' "$old" > "$shell_before"
                step "edit" "your shell: ${old##*/} -> zsh (everywhere after logging in again)"
            else
                warn "could not make zsh your shell" "by hand: chsh -s $zsh_path"
            fi
        fi
    fi
    # No login screen (display manager): the machine boots to a text console. How should
    # hyprland start after you log in there? Asked once: by itself, with a `start` command,
    # or neither (remembered). Not asked when the login file already starts it.
    if want hypr && command -v Hyprland > /dev/null && [[ ! -e /etc/systemd/system/display-manager.service ]]; then
        prof=$(login_profile) rc=$(login_rc)
        if [[ -n $prof && ! -e $no_start_ask ]] && ! loads_kawt "$prof" "$marker_login" && ! loads_kawt "$rc" "$marker_start" &&
            ! { [[ -f $prof ]] && grep -vE '^[[:space:]]*#' "$prof" | grep -E 'Hyprland|start-hyprland|uwsm start' > /dev/null; }; then
            how=-1
            if ((yes)); then
                how=0
            elif can_ask; then
                section "starting hyprland"
                say "${dim}  no login screen here. after you log in on the console: · ↑↓ move · enter pick${off}"
                choose how "by itself|hyprland starts right away on tty1 (recommended)" \
                    "a command|you type start" \
                    "neither|you start it your own way (not asked again)"
            fi
            case $how in
                0)
                    if [[ ! -e $prof ]]; then
                        mkdir -p "$(dirname "$prof")"
                        # a new ~/.bash_profile hides ~/.bashrc unless it reads it (like arch's default one)
                        [[ $prof == */.bash_profile ]] && printf '%s\n' '[[ -f ~/.bashrc ]] && . ~/.bashrc' > "$prof" || : > "$prof"
                    fi
                    hook "$prof" "$marker_login" "$line_login" && login_added=1 || warn "could not edit $prof"
                    ;;
                1)
                    if [[ -f $rc ]] && grep -vE '^[[:space:]]*#' "$rc" | grep -E '^[[:space:]]*(alias[[:space:]]+start=|start[[:space:]]*\(\))' > /dev/null; then
                        step "keep" "$rc already has a start command of its own"
                        mkdir -p "$state" && : > "$no_start_ask"
                    else
                        [[ -e $rc ]] || : > "$rc"
                        hook "$rc" "$marker_start" "$line_start" && start_added=1 || warn "could not edit $rc"
                    fi
                    ;;
                2)
                    mkdir -p "$state" && : > "$no_start_ask"
                    note "not asked again (to be asked: rm $no_start_ask)"
                    ;;
            esac
        fi
    fi
    if want shell && compgen -G "/sys/class/bluetooth/*" > /dev/null && command -v bluetoothctl > /dev/null && ! systemctl is-active --quiet bluetooth 2> /dev/null; then
        ask "bluetooth is off: start it now and at boot?" 1 && sudo systemctl enable --now bluetooth
    fi
    if want extras && command -v ollama > /dev/null && ! systemctl is-active --quiet ollama 2> /dev/null; then
        ask "start ollama (the ai panel's local model server) now and at boot?" 1 && sudo systemctl enable --now ollama
    fi
    if want extras && command -v powerprofilesctl > /dev/null && ! systemctl is-active --quiet power-profiles-daemon 2> /dev/null; then
        ask "start power-profiles-daemon (saver / balanced / perf in the battery panel)?" 1 && sudo systemctl enable --now power-profiles-daemon
    fi
    # networkmanager asks a server every few minutes whether there is internet: the one thing on
    # a fresh arch that goes out by itself. It's how it finds wifi login pages (cafés, hotels),
    # so it stays on unless you say so; --yes doesn't
    if want shell && ((!yes)) && can_ask && command -v NetworkManager > /dev/null && [[ ! -e $nm_quiet ]]; then
        conn=$(NetworkManager --print-config 2> /dev/null | awk '/^\[/ { s = ($0 == "[connectivity]"); next } s')
        uri=$(printf '%s\n' "$conn" | sed -n 's/^uri=//p' | tail -n 1)
        if [[ -n $uri ]] && ! printf '%s\n' "$conn" | grep -x 'enabled=false' > /dev/null; then
            host=${uri#*://} host=${host%%/*}
            if ask "networkmanager asks $host every few minutes if there's internet (finds wifi login pages). switch that off?" 1; then
                if printf '# %s (./install.sh --uninstall takes it back)\n[connectivity]\nenabled=false\n' "$marker_nm" | sudo tee "$nm_quiet" > /dev/null && sudo systemctl reload NetworkManager; then
                    step "edit" "$nm_quiet (no more internet checks)"
                else
                    warn "could not switch it off" "by hand: see ./doctor.sh, network"
                fi
            fi
        fi
    fi
fi

# ddcutil reaches the monitors through /dev/i2c-*: the i2c-dev module, which nothing loads by
# default. Asked once, after an update too (ddcutil may have just come with it)
if ((!dry)) && want shell && command -v ddcutil > /dev/null && ! compgen -G "/sys/class/backlight/*" > /dev/null &&
    [[ ! -e $no_i2c_ask ]] && ! grep -rsE '^[[:space:]]*i2c[-_]dev' /etc/modules-load.d /usr/lib/modules-load.d > /dev/null; then
    if ask "the monitors' brightness from the bar (ddcutil) needs the i2c-dev module: load it now and at every boot?" 1; then
        if printf '# %s (./install.sh --uninstall takes it back)\ni2c-dev\n' "$marker_i2c" | sudo tee "$i2c_conf" > /dev/null && sudo modprobe i2c-dev; then
            step "edit" "$i2c_conf (i2c-dev at boot; kawt finds the monitors at its next start)"
        else
            warn "could not load i2c-dev" "by hand: echo i2c-dev | sudo tee $i2c_conf && sudo modprobe i2c-dev"
        fi
    elif can_ask; then
        mkdir -p "$state" && : > "$no_i2c_ask"
        note "not asked again (to be asked: rm $no_i2c_ask)"
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
# after an update: what changed comes in without logging out
if [[ -n $updated_from ]]; then
    diff=""
    ((nothing_new)) || diff=$(git -C "$repo" diff --name-only "$updated_from" HEAD 2> /dev/null)
    ((nothing_new && !touched)) || section "reload"
    if want shell && ((!nothing_new || touched)) && [[ -n ${WAYLAND_DISPLAY:-} ]] && { pgrep -x qs > /dev/null || pgrep -x quickshell > /dev/null; }; then
        qs kill -c kawt-shell > /dev/null 2>&1
        for _ in {1..30}; do
            pgrep -f 'qs -c kawt-shell' > /dev/null || break
            sleep 0.1
        done
        # in a session of its own: it outlives this script and the terminal it runs in
        if setsid -f qs -c kawt-shell -d > /dev/null 2>&1; then pass "the shell started again"; else warn "could not start the shell again" "qs -c kawt-shell -d"; fi
    fi
    if want hypr && grep -E '^quickshell/kawt-shell/hypr/' <<< "$diff" > /dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        hyprctl reload > /dev/null 2>&1 && pass "hyprland read its config again"
    fi
    if want kitty && grep -Fx 'kitty/kitty.conf' <<< "$diff" > /dev/null && pgrep -x kitty > /dev/null; then
        pkill -USR1 -x kitty && pass "kitty read its config again"
    fi
    ((nothing_new && !touched)) || say ""
    if ((nothing_new)); then
        say "${acc}kawt is up to date, and all it needs is here.${off}"
    else
        say "${acc}kawt is updated.${off} ${dim}all of what's new: git -C $(short "$repo") log --oneline ${updated_from:0:7}..${off}"
    fi
    [[ -d $backup ]] && say "${dim}configs moved aside: $(short "$backup")${off}"
    exit 0
fi
[[ -d $backup ]] && say "${dim}old configs are in $(short "$backup")  (undo: ./install.sh --uninstall)${off}"
say "${acc}done.${off} start kawt:  ${acc}qs kill -c kawt-shell; qs -c kawt-shell -d${off}  ${dim}(or log in to hyprland again)${off}"
if want zsh && command -v zsh > /dev/null; then
    sh_now=$(login_shell)
    if [[ -z $sh_now || $sh_now == */zsh ]]; then
        say "the new prompt shows up in new terminals ${dim}(or now: exec zsh)${off}"
    else
        say "the prompt is in zsh, but terminals still open ${sh_now##*/}: ${acc}chsh -s $(command -v zsh)${off} ${dim}(or just try it: zsh)${off}"
    fi
fi
want fastfetch && say "try: ${acc}fastfetch${off}"
((nv_driver)) && say "${acc}reboot${off} once: the nvidia driver loads at the next start ${dim}(sudo reboot)${off}"
((nv_driver && nv_other)) && say "${dim}hybrid: prime-run <app> runs an app on the nvidia card (games, blender)${off}"
((${login_added:-0})) && say "from now on: log in on tty1 and hyprland starts ${dim}(other consoles, ctrl+alt+F2..., stay text)${off}"
((${start_added:-0})) && say "from now on: log in, then type ${acc}start${off} and hyprland starts"
if ((!is_arch)); then
    say "${acc}still to get${off} on ${os_name:-this system} (kawt couldn't install them here): $(needs_list)"
    say "${dim}quickshell for your system: https://quickshell.org (install guide); some systems have a package (fedora: copr, nixos)${off}"
fi
say "${dim}first time? super + / shows every key.  ./doctor.sh says what's wrong if something is.${off}"
exit 0
