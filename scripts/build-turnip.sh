#!/usr/bin/env bash
# Builds Mesa's Turnip, the Vulkan driver for Adreno GPUs, on its own for a
# handheld running ArmadaOS (Fedora 44): libvulkan_freedreno.so and an ICD
# manifest that names it by a relative path. Like the Turnip the Android
# build bundles, the game can load it without installing anything:
#
#   VK_DRIVER_FILES=/path/to/freedreno_icd.json python3 tools/pinyon.py launch
#
#   scripts/build-turnip.sh OUTDIR [REF]
#
# Runs as root in a fedora:44 arm64 container. REF is a Mesa tag or branch,
# by default the newest mesa-X.Y.Z release. Writes
# OUTDIR/pinyon-arm64-turnip-VERSION.tar.xz, VERSION being Mesa's version,
# with the commit for a branch.
set -euo pipefail

out="$(mkdir -p "$1" && cd "$1" && pwd)"
ref="${2:-}"
repo=https://gitlab.freedesktop.org/mesa/mesa.git

if [ "$(uname -m)" != aarch64 ]; then
    echo "error: run this in an arm64 fedora:44 container" >&2
    exit 1
fi

dnf -y -q install dnf5-plugins git xz binutils jq
# Fedora's own build dependencies of Mesa, so a newer Mesa finds what it needs.
dnf -y -q builddep --enablerepo='fedora-source' --enablerepo='updates-source' mesa
dnf -y -q install python3-pyyaml python3-packaging glslang
# Mesa links SPIRV-Tools when it finds it, and a handheld may not have it.
rpm -e --nodeps spirv-tools-devel 2>/dev/null || true

if [ -z "$ref" ]; then
    ref="$(git ls-remote --tags --refs "$repo" 'mesa-*' | sed 's#.*refs/tags/##' \
        | grep -E '^mesa-[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)"
fi
work="$(mktemp -d)"
git clone -q --depth 1 --branch "$ref" "$repo" "$work/mesa"
commit="$(git -C "$work/mesa" rev-parse --short=10 HEAD)"
version="$(cat "$work/mesa/VERSION")"
case "$ref" in
    mesa-*) ;;
    *) version="$version-$commit" ;;
esac
echo "Building Turnip from Mesa $ref ($commit) as $version"

# Turnip alone, for the kernel's msm driver, with X11 and Wayland windows.
# Optional libraries a handheld may lack stay off.
meson setup "$work/build" "$work/mesa" --prefix=/usr --buildtype=release -Db_ndebug=true \
    -Dvulkan-drivers=freedreno -Dfreedreno-kmds=msm -Dgallium-drivers= \
    -Dplatforms=x11,wayland -Dopengl=false -Dglx=disabled -Degl=disabled -Dgbm=disabled \
    -Dgles1=disabled -Dgles2=disabled -Dllvm=disabled -Dvulkan-layers= -Dtools= \
    -Dbuild-tests=false -Dvalgrind=disabled -Dlibunwind=disabled -Dlmsensors=disabled
ninja -C "$work/build" src/freedreno/vulkan/libvulkan_freedreno.so \
    src/freedreno/vulkan/freedreno_icd.aarch64.json

name="pinyon-arm64-turnip-$version"
package="$work/$name"
mkdir -p "$package"
install -m 755 "$work/build/src/freedreno/vulkan/libvulkan_freedreno.so" "$package/"
strip --strip-unneeded "$package/libvulkan_freedreno.so"
# A relative library_path is resolved from the manifest's own folder.
jq '.ICD.library_path = "./libvulkan_freedreno.so"' \
    "$work/build/src/freedreno/vulkan/freedreno_icd.aarch64.json" > "$package/freedreno_icd.json"
cp "$work/mesa/docs/license.rst" "$package/LICENSE.rst"
printf 'Mesa %s (%s, commit %s)\n' "$version" "$ref" "$commit" > "$package/VERSION"
readelf -d "$package/libvulkan_freedreno.so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' \
    > "$package/NEEDED.txt"

tar -C "$work" --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -cf - "$name" \
    | xz -T0 -9 > "$out/$name.tar.xz"
cat "$package/freedreno_icd.json" "$package/NEEDED.txt"
du -h "$out/$name.tar.xz"
