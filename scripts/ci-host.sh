#!/usr/bin/env bash
# Builds and tests everything of the ARM64 port that needs no game files, on
# an aarch64 Linux machine: the pinned toolchain, the ShiftGlue translator,
# the runtime and GPU plugin, and the host tests.
#
#   scripts/ci-host.sh SOURCE   (a tree made by prepare-source.sh)
set -euo pipefail

src="$(cd "$1" && pwd)"
cd "$src"
jobs="${JOBS:-$(nproc)}"

# The pinned CMake, Ninja and LLVM, ShiftGlue at its pinned revision, and the
# host checks setup makes (ld.lld, pkg-config modules).
python3 tools/pinyon.py setup --tools-only

if [ -f thirdparty/shiftglue-sdk/CMakeLists.txt ]; then
    sdk="$src/thirdparty/shiftglue-sdk"
else
    sdk="$src/.local/rexglue"
fi
toolchain="$src/.local/toolchain"
export PINYON_LINUX_TOOLCHAIN="$toolchain/linux-arm64"
cmake_bin="$(echo "$toolchain"/cmake-*-linux-aarch64/bin)"
ninja_dir="$(echo "$toolchain"/ninja-*-linux-aarch64)"
export PATH="$cmake_bin:$ninja_dir:$PATH"
llvm="$PINYON_LINUX_TOOLCHAIN/llvm/bin"

echo "::group::ShiftGlue translator"
(cd "$sdk" && cmake --preset linux-arm64 -DREXGLUE_ENABLE_TRACY=OFF -DSDL_HIDAPI_LIBUSB=OFF \
    "-DCMAKE_TOOLCHAIN_FILE=$src/cmake/toolchains/linux-arm64.cmake" \
    "-DCMAKE_C_COMPILER=$llvm/clang" "-DCMAKE_CXX_COMPILER=$llvm/clang++")
(cd "$sdk" && cmake --build --preset linux-arm64-release --target rexglue --parallel "$jobs")
"$sdk/out/linux-arm64/Release/rexglue" --version
echo "::endgroup::"

echo "::group::Runtime, GPU plugin and host tests"
build="$src/out/build/ci-arm64"
cmake --preset linux-arm64-release -B "$build" "-DREXSDK_DIR=$sdk" \
    -DPINYON_SHIFT_HOST_TESTS_ONLY=ON -DREXGLUE_ENABLE_TRACY=OFF -DSDL_HIDAPI_LIBUSB=OFF
cmake --build "$build" --target pinyon_shift_host_tests rexgpu-fh1 --parallel "$jobs"
echo "::endgroup::"

failed=()
for test in pinyon_shift_fh1_ui_api_tests pinyon_shift_hostui_tests \
        pinyon_shift_host_config_tests pinyon_shift_profile_body_tests \
        pinyon_shift_rally_progress_tests pinyon_shift_rally_pace_tests \
        pinyon_shift_car_cards_tests pinyon_shift_save_backups_tests \
        pinyon_shift_content_roots_tests pinyon_shift_overlay_device_tests \
        pinyon_shift_fh1_edram_tiles_tests; do
    if LD_LIBRARY_PATH="$build/rexglue-artifacts" "$build/$test"; then
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
