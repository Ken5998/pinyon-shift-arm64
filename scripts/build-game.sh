#!/usr/bin/env bash
# Builds the game for ARM64 Linux from your own disc on an x86-64 Ubuntu
# machine (WSL included, after wsl-setup.sh) or on an ARM64 Linux machine,
# and stages what the handheld needs in WORKDIR/device/PinyonShift.
#
#   scripts/build-game.sh --iso FILE [--tag TAG] [--workdir DIR] [--jobs N]
#
# TAG defaults to the upstream release in upstream.json. The pinned
# toolchain is downloaded once into WORKDIR/toolchain and shared by every
# release. Nothing built here may be published (upstream docs/LEGAL.md).
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
iso="" tag="" jobs=""
workdir="${PINYON_ARM64_WORKDIR:-$HOME/pinyon-shift-arm64-work}"
while [ $# -gt 0 ]; do
    case "$1" in
        --iso) iso="$2"; shift 2 ;;
        --tag) tag="$2"; shift 2 ;;
        --workdir) workdir="$2"; shift 2 ;;
        --jobs) jobs="$2"; shift 2 ;;
        *) echo "error: unknown argument $1" >&2; exit 2 ;;
    esac
done
[ -f "$iso" ] || { echo "error: --iso FILE is required" >&2; exit 2; }
iso="$(cd "$(dirname "$iso")" && pwd)/$(basename "$iso")"
[ -n "$tag" ] || tag="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["tag"])' "$here/upstream.json")"
mkdir -p "$workdir/toolchain" "$workdir/downloads"
workdir="$(cd "$workdir" && pwd)"
src="$workdir/source-$tag"

if [ ! -d "$src/.git" ]; then
    "$here/scripts/prepare-source.sh" "$src" "$tag"
fi
mkdir -p "$src/.local"
for shared in toolchain downloads; do
    [ -e "$src/.local/$shared" ] || ln -s "$workdir/$shared" "$src/.local/$shared"
done

target=()
case "$(uname -m)" in
    x86_64|amd64) target=(--target linux-arm64) ;;
    aarch64|arm64) ;;
    *) echo "error: build on x86-64 or ARM64 Linux" >&2; exit 1 ;;
esac
(cd "$src" && python3 tools/pinyon.py setup --iso "$iso" "${target[@]}" ${jobs:+--jobs "$jobs"})

# What tools/pinyon.py launch reads on the handheld: the tracked files, the
# verified game files and the game, its libraries and tools from the build.
build="out/build/linux-arm64-release"
stage="$workdir/device/PinyonShift"
mkdir -p "$stage"
(cd "$src" && git ls-files -z) | rsync -a --from0 --files-from=- "$src/" "$stage/"
rsync -a --delete "$src/.local/game/" "$stage/.local/game/"
mkdir -p "$stage/$build"
find "$src/$build" -maxdepth 1 -type f \( -name 'pinyon_shift*' -o -name '*.so*' \
    -o -name '*.txt' -o -name '*.json' \) ! -name 'CMakeCache.txt' \
    -exec cp -p {} "$stage/$build/" \;
file "$stage/$build/pinyon_shift" | grep -q 'ARM aarch64' \
    || { echo "error: $stage/$build/pinyon_shift is not an ARM64 program" >&2; exit 1; }
echo "$tag" > "$stage/.pinyon-arm64-release"
echo "$tag" > "$workdir/built-release"

# Earlier releases' trees hold tens of GB of generated code; keep this one.
for old in "$workdir"/source-*; do
    if [ "$old" != "$src" ] && [ -d "$old/.git" ]; then
        echo "Removing the previous build tree $old"
        rm -rf -- "$old"
    fi
done
echo "Built $tag. Copy $stage to the handheld, or run scripts/deploy.sh."
