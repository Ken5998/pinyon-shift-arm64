#!/usr/bin/env bash
# For a daily timer on the build machine: pulls this repository and, when
# upstream.json names a release the machine has not built yet (the weekly CI
# moves it after a green ARM64 build), builds it and deploys it.
#
# Reads WORKDIR/auto-update.conf:
#   ISO=/path/to/forza-horizon.iso
#   DEVICE=user@retroid          (optional; without it the game is only staged)
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
workdir="${PINYON_ARM64_WORKDIR:-$HOME/pinyon-shift-arm64-work}"
conf="$workdir/auto-update.conf"
[ -f "$conf" ] || { echo "error: write $conf first (ISO=..., DEVICE=...)" >&2; exit 1; }
# shellcheck source=/dev/null
. "$conf"

git -C "$here" pull --ff-only --quiet
tag="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["tag"])' "$here/upstream.json")"
if [ "$(cat "$workdir/built-release" 2>/dev/null)" = "$tag" ]; then
    echo "$tag is already built."
    exit 0
fi
"$here/scripts/build-game.sh" --iso "$ISO" --tag "$tag" --workdir "$workdir"
if [ -n "${DEVICE:-}" ]; then
    "$here/scripts/deploy.sh" "$DEVICE" --workdir "$workdir"
fi
