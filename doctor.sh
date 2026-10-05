#!/usr/bin/env bash
# kawt doctor: checks the whole chain "pick a theme -> files written -> apps read them"
# and says where it breaks. Changes nothing.
#   ./doctor.sh

config=${XDG_CONFIG_HOME:-$HOME/.config}
state=${XDG_STATE_HOME:-$HOME/.local/state}/kawt
zshrc=${ZDOTDIR:-$HOME}/.zshrc
problems=0

if [[ -t 1 ]]; then ok=$'\e[1m[ ok ]\e[0m' bad=$'\e[1;31m[ !! ]\e[0m' dim=$'\e[2m' off=$'\e[0m'; else ok='[ ok ]' bad='[ !! ]' dim='' off=''; fi
good() { printf '%s %s\n' "$ok" "$1"; }
fail() { printf '%s %s\n' "$bad" "$1"; [[ -n ${2:-} ]] && printf '       %s%s%s\n' "$dim" "$2" "$off"; problems=$((problems + 1)); }
info() { printf '       %s%s%s\n' "$dim" "$1" "$off"; }
# a "key": value from settings.json (pretty-printed by quickshell)
setting() { sed -n "s/^ *\"$1\": *\"\{0,1\}\([^\",]*\)\"\{0,1\},\{0,1\} *$/\1/p" "$state/settings.json" 2> /dev/null | head -n 1; }

echo "-- shell"
# by process name: matching the command line would also find this very script
if pgrep -x qs > /dev/null || pgrep -x quickshell > /dev/null; then good "quickshell is running"; else fail "quickshell is not running" "start kawt: qs -c kawt-shell -d"; fi
if [[ -f $config/quickshell/kawt-shell/shell.qml ]]; then
    good "config: $(readlink -f "$config/quickshell/kawt-shell")"
else
    fail "~/.config/quickshell/kawt-shell is missing or a broken link" "run ./install.sh"
fi

echo "-- theme"
theme=$(setting theme) light=$(setting light) term=$(setting termColors)
want="${theme:-mono}-$([[ $light == true ]] && echo light || echo dark)"
info "settings.json: theme=${theme:-mono} light=${light:-false} terminal=${term:-soft}  ->  $want"
if [[ -f $state/theme/kitty.conf ]]; then
    have=$(sed -n '1s/.*kawt theme: \([^ ]*\).*/\1/p' "$state/theme/kitty.conf")
    if [[ $have == "$want" ]]; then
        good "generated colors are for $have ($(date -r "$state/theme/kitty.conf" '+%d.%m %H:%M'))"
    else
        fail "generated colors are for '$have', but the theme is '$want'" "kawt didn't rewrite them: switch the theme once in super+w (kawt must be running)"
    fi
else
    fail "no generated colors in ${state/#$HOME/\~}/theme/" "start kawt once, it writes them on startup"
fi

echo "-- kitty"
kc=$config/kitty/kitty.conf
if [[ ! -e $kc ]]; then
    fail "no kitty.conf" "run ./install.sh"
else
    [[ -L $kc ]] && good "kitty.conf -> $(readlink -f "$kc")" || info "kitty.conf is your own file, not kawt's"
    if grep -E '^[[:space:]]*include[[:space:]].*kawt/theme/kitty.conf' "$kc" > /dev/null; then
        good "kitty.conf includes the kawt colors"
    else
        fail "kitty.conf doesn't include the kawt colors" "add: include ~/.local/state/kawt/theme/kitty.conf"
    fi
    # anything after the include that sets colors overrides the theme
    after=$(awk '/include .*kawt\/theme\/kitty.conf/ {seen = 1; next} seen && /^[[:space:]]*(foreground|background|color[0-9]+|include)[[:space:]]/ {print NR": "$0}' "$kc")
    [[ -n $after ]] && fail "kitty.conf sets colors after the kawt include, these win:" "$after"
fi
info "open terminals recolor on a theme switch only if 'recolor open terminals' is on in super+w"

echo "-- hyprland"
hl=$config/hypr/hyprland.lua
if [[ -f $hl ]]; then
    grep -vE '^[[:space:]]*--' "$hl" | grep -F "kawt-shell/hypr/kawt.lua" > /dev/null && good "hyprland.lua loads kawt" || fail "hyprland.lua doesn't load kawt" "run ./install.sh"
    [[ -f $state/theme/hyprland_colors.lua ]] && good "border colors file exists" || fail "no hyprland_colors.lua yet" "switch the theme once in super+w"
fi

echo "-- zsh prompt"
if [[ -f $zshrc ]]; then
    if grep -vE '^[[:space:]]*#' "$zshrc" | grep -F "kawt-shell/zsh/kawt.zsh-theme" > /dev/null; then
        good ".zshrc loads the kawt prompt"
        # a PROMPT set after our line would replace it
        late=$(awk '/kawt-shell\/zsh\/kawt.zsh-theme/ {seen = 1; next} seen && /^[[:space:]]*(PROMPT|PS1|source .*(p10k|powerlevel|starship|oh-my-posh))/ {print NR": "$0}' "$zshrc")
        [[ -n $late ]] && fail "something after the kawt line replaces the prompt:" "$late"
    else
        fail ".zshrc doesn't load the kawt prompt" "run ./install.sh"
    fi
    grep -E 'powerlevel10k|p10k|starship init|oh-my-posh' "$zshrc" | grep -vE '^[[:space:]]*#' > /dev/null &&
        fail "a prompt engine is still active in .zshrc (powerlevel10k / starship / oh-my-posh)" "those set their own (truecolor) colors; comment them out"
else
    info "no .zshrc"
fi

echo "-- features"
# kawt.lua is loaded with dofile: hyprland doesn't see edits to it until a reload
if command -v hyprctl > /dev/null; then
    if hyprctl binds 2> /dev/null | grep -F "kawt record" > /dev/null; then
        good "hyprland has the current kawt binds"
    else
        fail "hyprland runs older kawt binds (recording keys are missing)" "hyprctl reload"
    fi
fi
for tool in wf-recorder:recording grim:screenshots slurp:"area selection" cliphist:"clipboard history"; do
    command -v "${tool%%:*}" > /dev/null && good "${tool%%:*}" || fail "${tool%%:*} is missing (${tool#*:})" "sudo pacman -S ${tool%%:*}"
done
if ls /sys/class/bluetooth 2> /dev/null | grep -q .; then
    if systemctl is-active --quiet bluetooth 2> /dev/null; then
        good "bluetooth service is running"
    else
        fail "bluetooth service isn't running" "sudo pacman -S --needed bluez bluez-utils && sudo systemctl enable --now bluetooth"
    fi
fi

echo "-- ai (ollama)"
model=$(setting ollamaModel)
url=$(setting ollamaUrl)
url=${url:-http://localhost:11434}
if ! command -v ollama > /dev/null; then
    fail "ollama is not installed" "sudo pacman -S ollama   (or ollama-rocm / ollama-cuda for the gpu)"
elif ! tags=$(curl -s -m 3 "$url/api/tags"); then
    fail "ollama doesn't answer at $url" "start it: sudo systemctl enable --now ollama"
else
    good "ollama answers at $url"
    pulled=$(printf '%s' "$tags" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')
    if [[ -z $pulled ]]; then
        fail "no models downloaded" "ollama pull ${model:-llama3.2}"
    elif [[ " $pulled " == *" ${model:-llama3.2} "* || " $pulled " == *" ${model:-llama3.2}:latest "* ]]; then
        good "model ${model:-llama3.2} is downloaded"
    else
        fail "kawt uses model '${model:-llama3.2}', but it isn't downloaded" "ollama pull ${model:-llama3.2}   (downloaded: $pulled)"
    fi
fi

echo
if ((problems)); then echo "$problems problem(s) above"; else echo "all good. colors still off? run ./colortest.sh"; fi
