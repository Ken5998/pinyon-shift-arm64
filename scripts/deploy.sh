#!/usr/bin/env bash
# Copies the staged game to the handheld over SSH, keeping its saves and
# settings (.local/preview) in place.
#
#   scripts/deploy.sh USER@HOST [--workdir DIR]
set -euo pipefail

device="${1:?usage: scripts/deploy.sh USER@HOST [--workdir DIR]}"
shift
workdir="${PINYON_ARM64_WORKDIR:-$HOME/pinyon-shift-arm64-work}"
[ "${1:-}" = "--workdir" ] && workdir="$2"
stage="$workdir/device/PinyonShift"
[ -f "$stage/.pinyon-arm64-release" ] || { echo "error: nothing staged in $stage" >&2; exit 1; }
rsync -a --delete --info=progress2 --exclude '/.local/preview/' --exclude '/.local/logs/' \
    "$stage/" "$device:PinyonShift/"
echo "Deployed $(cat "$stage/.pinyon-arm64-release") to $device:~/PinyonShift"
