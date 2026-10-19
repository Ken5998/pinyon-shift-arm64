#!/usr/bin/env bash
# Builds and tests everything of the ARM64 port that needs no game files: the
# pinned toolchain, the ShiftGlue translator, the ARM64 runtime and GPU
# plugin, and the host tests.
#
#   scripts/ci-host.sh SOURCE   (a tree made by prepare-source.sh)
#
# On aarch64 Linux everything builds natively. On x86-64 Linux (after
# wsl-setup.sh) it takes the PC path of build-game.sh: the translator for
# x86-64, the rest cross-compiled for aarch64 and the tests run under qemu.
set -euo pipefail

src="$(cd "$1" && pwd)"
cd "$src"
jobs="${JOBS:-$(nproc)}"

case "$(uname -m)" in
    aarch64|arm64) host=linux-arm64 sdk_preset=linux-arm64 setup_args=()
                   host_toolchain=linux-arm64.cmake target_folder=linux-arm64 run=() ;;
    x86_64|amd64) host=linux-x86_64 sdk_preset=linux-amd64 setup_args=(--target linux-arm64)
                  host_toolchain=linux-x86_64-sniper.cmake target_folder=linux-arm64-cross
                  run=(qemu-aarch64-static -L /usr/aarch64-linux-gnu) ;;
    *) echo "error: unsupported host $(uname -m)" >&2; exit 1 ;;
esac

# The pinned CMake, Ninja and LLVM (and on x86-64 the Steam Runtime sysroot),
# ShiftGlue at its pinned revision, and the checks setup makes.
python3 tools/pinyon.py setup --tools-only "${setup_args[@]}"

tool() {  # tool KEY: the pinned tool's folder for this host
    python3 -c 'import json, sys
item = json.load(open("config/release-toolchain.json"))["posix"][sys.argv[1]][sys.argv[2]]
print(item["install_path"])' "$host" "$1"
}
export PATH="$src/$(tool cmake)/bin:$src/$(tool ninja):$PATH"
if [ -f thirdparty/shiftglue-sdk/CMakeLists.txt ]; then
    sdk="$src/thirdparty/shiftglue-sdk"
else
    sdk="$src/.local/rexglue"
fi
toolchains="$src/.local/toolchain"

echo "::group::ShiftGlue translator ($host)"
llvm="$toolchains/$host/llvm/bin"
(cd "$sdk" && PINYON_LINUX_TOOLCHAIN="$toolchains/$host" cmake --preset "$sdk_preset" \
    -DREXGLUE_ENABLE_TRACY=OFF -DSDL_HIDAPI_LIBUSB=OFF \
    "-DCMAKE_TOOLCHAIN_FILE=$src/cmake/toolchains/$host_toolchain" \
    "-DCMAKE_C_COMPILER=$llvm/clang" "-DCMAKE_CXX_COMPILER=$llvm/clang++")
(cd "$sdk" && PINYON_LINUX_TOOLCHAIN="$toolchains/$host" \
    cmake --build --preset "$sdk_preset-release" --target rexglue --parallel "$jobs")
"$sdk/out/$sdk_preset/Release/rexglue" --version
echo "::endgroup::"

echo "::group::ARM64 runtime, GPU plugin and host tests"
build="$src/out/build/ci-arm64"
export PINYON_LINUX_TOOLCHAIN="$toolchains/$target_folder"
cmake --preset linux-arm64-release -B "$build" "-DREXSDK_DIR=$sdk" \
    -DPINYON_SHIFT_HOST_TESTS_ONLY=ON -DREXGLUE_ENABLE_TRACY=OFF -DSDL_HIDAPI_LIBUSB=OFF
cmake --build "$build" --target pinyon_shift_host_tests rexgpu-fh1 --parallel "$jobs"
echo "::endgroup::"

file "$build/rexglue-artifacts/librexgpu-fh1.so" | grep -q 'ARM aarch64'

# The game build configures the FidelityFX library as its own project and
# passes it only the compilers; it takes the toolchain from the environment
# setup gives the build (patch 0008).
echo "::group::FidelityFX library"
ffx="$src/out/build/ci-fidelityfx"
toolchain_file="$(python3 -c 'import sys; sys.path.insert(0, "tools"); import pinyon_setup
print(pinyon_setup.build_environment({}, "linux-arm64")["CMAKE_TOOLCHAIN_FILE"])')"
CMAKE_TOOLCHAIN_FILE="$toolchain_file" cmake -S "$sdk/thirdparty/fidelityfx-vk" -B "$ffx" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release "-DCMAKE_C_COMPILER=$PINYON_LINUX_TOOLCHAIN/llvm/bin/clang" \
    "-DCMAKE_CXX_COMPILER=$PINYON_LINUX_TOOLCHAIN/llvm/bin/clang++"
cmake --build "$ffx" --target amd_fidelityfx_vk --parallel "$jobs"
echo "::endgroup::"
file -L "$ffx/ffx-api/libamd_fidelityfx_vk.so" | grep -q 'ARM aarch64'
failed=()
for test in pinyon_shift_fh1_ui_api_tests pinyon_shift_hostui_tests \
        pinyon_shift_host_config_tests pinyon_shift_profile_body_tests \
        pinyon_shift_rally_progress_tests pinyon_shift_rally_pace_tests \
        pinyon_shift_car_cards_tests pinyon_shift_save_backups_tests \
        pinyon_shift_content_roots_tests pinyon_shift_overlay_device_tests \
        pinyon_shift_fh1_edram_tiles_tests; do
    if LD_LIBRARY_PATH="$build/rexglue-artifacts" "${run[@]}" "$build/$test"; then
        echo "PASS $test"
    else
        echo "FAIL $test"
        failed+=("$test")
    fi
done
if [ "${#failed[@]}" -ne 0 ]; then
    echo "Host tests failed: ${failed[*]}" >&2
    exit 1
fi
echo "Host tests passed."
