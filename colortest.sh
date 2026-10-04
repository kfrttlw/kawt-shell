#!/usr/bin/env bash
# Shows the three kinds of terminal color, to find where an off-theme color comes from.
# Rows 1 and 2 follow the kawt theme; row 3 (truecolor) can't, it's hardcoded by the program.
#   ./colortest.sh

r=$'\e[0m'
printf '\n 1. the 16 colors (kawt theme)\n    '
for i in {0..15}; do printf '\e[38;5;%sm%3s ' "$i" "$i"; done
printf '%s\n\n 2. 256-color palette (kawt theme too, since the update)\n    ' "$r"
for i in 21 27 33 39 45 51 75 81 117 159 160 202 214 226 46 82 129 201 231 255; do printf '\e[38;5;%sm%3s ' "$i" "$i"; done
printf '%s\n\n 3. truecolor (fixed by each program, no theme can change it)\n    ' "$r"
for c in "0;135;255" "0;175;255" "95;215;255" "255;255;255" "255;85;85" "85;255;85"; do printf '\e[38;2;%sm#%-6s' "$c" "$(printf '%02x' ${c//;/ })"; done
printf '%s\n\nif an off color in your prompt/ls looks like row 3, that program uses truecolor:\n' "$r"
printf 'switch its theme to "terminal colors" / "ansi" (e.g. p10k: POWERLEVEL9K_* = 0-15 or 16-255)\n\n'
