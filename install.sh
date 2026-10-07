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
    "extras|extras|ollama (local ai), cava, fortune, wallpapers, night light, power profiles"
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

cursor_back() { printf '\e[?25h' 2> /dev/null > /dev/tty; } # stderr first: no tty, no message
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
    local items=("$@") n=$# cur=0 i name what k
    printf '\e[?25l' > /dev/tty
    while :; do
        for i in "${!items[@]}"; do
            name=${items[i]%%|*} what=${items[i]#*|}
            if ((i == cur)); then
                printf '\e[2K %s> %-14s%s %s\n' "$acc" "$name" "$off" "$what" > /dev/tty
            else
                printf '\e[2K   %-14s %s%s%s\n' "$name" "$dim" "$what" "$off" > /dev/tty
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
    local items=("$@") n=$# cur=0 i name what box k
    printf '\e[?25l' > /dev/tty
    while :; do
        for i in "${!items[@]}"; do
            name=${items[i]%%|*} what=${items[i]#*|}
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

# ------------------------------------------------------------------ 1. what
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

if ! command -v pacman > /dev/null; then
    packages=0
    update=0
    no_pacman=1
fi
if ((packages)) && [[ -z $preset ]] && can_ask; then
    section "packages"
    say "${dim}  ↑↓ move · space on/off · enter go on${off}"
    opts=("$packages" "$update")
    pick opts "install them|what's missing, with pacman (and paru / yay for the aur)" \
        "update first|the whole system (pacman -Syu): arch doesn't like half-updated systems"
    packages=${opts[0]}
    update=$((opts[0] && opts[1]))
fi

# ------------------------------------------------------------------ 2. packages
installed() { pacman -T -- "$1" > /dev/null 2>&1; } # also true for a package that provides it (quickshell-git)
in_repos() { pacman -Si -- "$1" > /dev/null 2>&1; }

repo_pkgs=() aur_pkgs=() have=0
if ((packages)); then
    wanted=()
    for id in shell hypr kitty zsh fastfetch extras; do
        want "$id" || continue
        declare -n list="pkgs_$id"
        wanted+=("${list[@]}")
        unset -n list
    done
    want shell && compgen -G "/sys/class/backlight/*" > /dev/null && wanted+=(brightnessctl)
    want shell && compgen -G "/sys/class/bluetooth/*" > /dev/null && wanted+=(bluez bluez-utils)
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

# ------------------------------------------------------------------ 3. the plan
section "plan"
names=()
for i in "${!parts[@]}"; do
    ((on[i])) && { p=${parts[i]#*|}; names+=("${p%%|*}"); }
done
if ((${#names[@]} == 0)); then
    say "nothing picked. ${dim}nothing was changed.${off}"
    exit 0
fi
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
        printf '  %-9s %s\n' "aur" "${aur_pkgs[*]}  ${dim}$( [[ -n $aur_helper ]] && printf 'with %s' "${aur_helper##*/}" || printf 'no paru / yay: shown how at the end')${off}"
    fi
elif ((${no_pacman:-0})); then
    printf '  %-9s %s\n' "packages" "${dim}no pacman here: install the needs yourself (see the readme)${off}"
else
    printf '  %-9s %s\n' "packages" "${dim}left alone${off}"
fi
printf '  %-9s %s\n' "then" "link the configs ${dim}(what's there now goes to $(short "$backup"))${off}"
say ""
if ! ask "go?"; then
    say "${dim}nothing was changed.${off}"
    exit 0
fi

# ------------------------------------------------------------------ 4. install packages
failed=0
if ((packages)); then
    section "packages"
    noconfirm=()
    ((yes)) && noconfirm=(--noconfirm)
    if ((update)); then
        run sudo pacman -Syu --needed "${noconfirm[@]}" "${repo_pkgs[@]}" || { fail "pacman failed" "see above; then run ./install.sh again"; failed=1; }
    elif ((${#repo_pkgs[@]})); then
        run sudo pacman -S --needed "${noconfirm[@]}" "${repo_pkgs[@]}" || { fail "pacman failed" "see above; then run ./install.sh again"; failed=1; }
    fi
    if ((${#aur_pkgs[@]})); then
        if [[ -n $aur_helper ]]; then
            run "$aur_helper" -S --needed "${noconfirm[@]}" "${aur_pkgs[@]}" || { fail "${aur_helper##*/} failed" "see above"; failed=1; }
        else
            warn "these are in the aur: ${aur_pkgs[*]}" "install an aur helper first: git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si"
        fi
    fi
    ((failed)) || pass "packages"
fi

# ------------------------------------------------------------------ 5. checks
section "checks"
need_cmd() { # need_cmd <command> <what for>
    if command -v "$1" > /dev/null; then pass "$1"; else fail "$1 not found" "$2"; fi
}
if want shell; then
    need_cmd qs "the shell itself (package quickshell)"
    need_cmd hyprctl "the compositor (package hyprland)"
    if fc-list : family 2> /dev/null | grep -F "JetBrainsMono Nerd Font" > /dev/null; then pass "JetBrainsMono Nerd Font"; else fail "JetBrainsMono Nerd Font not found" "the font of everything (ttf-jetbrains-mono-nerd)"; fi
    # NetworkManager isn't installed for you: next to iwd or systemd-networkd it can take the
    # network over. The wifi panel needs it, the rest of kawt doesn't
    if command -v nmcli > /dev/null; then
        systemctl is-active --quiet NetworkManager 2> /dev/null && pass "NetworkManager (wifi panel)" || warn "NetworkManager isn't running" "the wifi panel needs it: sudo systemctl enable --now NetworkManager"
    else
        warn "no NetworkManager: the wifi panel stays empty" "if you want it (and don't use iwd/networkd alone): sudo pacman -S networkmanager"
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

# ------------------------------------------------------------------ 6. configs
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

# ------------------------------------------------------------------ 7. services
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

# ------------------------------------------------------------------ 8. verify
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
say "${dim}first time? super + / shows every key.  ./doctor.sh says what's wrong if something is.${off}"
exit 0
