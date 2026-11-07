#!/usr/bin/env bash
# Builds kawt's shaders again after a change: quickshell/kawt-shell/shaders/*.frag -> *.frag.qsb
# (the .qsb files are in the repo, so nobody else needs this). qsb is in qt6-shadertools:
#   sudo pacman -S qt6-shadertools
# Only the GLSL that Linux uses and SPIR-V (vulkan) go in.
set -euo pipefail

qsb=$(command -v qsb || command -v /usr/lib/qt6/bin/qsb || true)
if [[ -z $qsb ]]; then
    printf 'no qsb: sudo pacman -S qt6-shadertools\n' >&2
    exit 1
fi

dir=$(dirname "${BASH_SOURCE[0]}")/../quickshell/kawt-shell/shaders
for frag in "$dir"/*.frag; do
    "$qsb" --glsl "100 es,120,150" -o "$frag.qsb" "$frag"
    printf '%s\n' "${frag##*/}.qsb"
done
