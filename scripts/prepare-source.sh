#!/usr/bin/env bash
# Checks out an upstream Pinyon Shift release and applies the ARM64 patches.
#
#   scripts/prepare-source.sh DEST [TAG]
#
# TAG defaults to the release recorded in upstream.json. Stops with an error
# when a patch no longer applies, which is the signal that the port needs
# updating for that release.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
dest="$1"
read_json() { python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' \
    "$here/upstream.json" "$1"; }
repository="$(read_json repository)"
ref="${2:-$(read_json tag)}"

if [ -e "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    echo "error: $dest exists and is not empty" >&2
    exit 1
fi
git init -q "$dest"
git -C "$dest" remote add origin "$repository"
if ! git -C "$dest" fetch -q --depth 1 origin "refs/tags/$ref:refs/tags/$ref" 2>/dev/null; then
    git -C "$dest" fetch -q --depth 1 origin "$ref"
fi
git -C "$dest" -c advice.detachedHead=false checkout -q FETCH_HEAD
echo "Upstream $ref at $(git -C "$dest" rev-parse HEAD)"

for patch in "$here"/patches/*.patch; do
    echo "Applying $(basename "$patch")"
    git -C "$dest" -c user.name="pinyon-shift-arm64" -c user.email="pinyon-shift-arm64@users.noreply.github.com" \
        am --3way --quiet "$patch"
done

# The ARM64 sysroot in sysroot.json, if one is published.
python3 "$here/scripts/pin-sysroot.py" "$dest"
