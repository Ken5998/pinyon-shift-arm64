# Developing pinyon-shift-arm64

This repository is an overlay: patches on an upstream
[Pinyon Shift](https://github.com/arcanite24/pinyon-shift) release, the
scripts that apply and package them, and CI. The game is never built here or
on GitHub; upstream's
[LEGAL.md](https://github.com/arcanite24/pinyon-shift/blob/main/docs/LEGAL.md)
forbids distributing the disc, the generated translation or the binary.

## What is here

| Path | What it does |
| --- | --- |
| `patches/` | The port: `linux-arm64` CMake presets and toolchain, ARM64 support in `tools/pinyon_setup.py` (native with a pinned sysroot or the host's files, and cross from x86-64 with `--target linux-arm64`), the launcher on ARM64, the Android build's Adreno defaults at launch, docs. Applied with `git am` on an upstream release. |
| `upstream.json` | The last upstream release the patches were verified on. |
| `sysroot.json` | The published ARM64 sysroot the launcher downloads. |
| `scripts/prepare-source.sh DEST [TAG]` | Checks out an upstream release, applies the patches and pins the sysroot (`scripts/pin-sysroot.py`). |
| `scripts/build-sysroot.sh OUTDIR` | Builds the ARM64 sysroot from Ubuntu 24.04 arm64 packages, in an `ubuntu:24.04` arm64 container. |
| `scripts/package-launcher.sh SOURCE OUTDIR` | Packages the ARM64 launcher with the patched source, updates pointed at this repository. |
| `scripts/wsl-setup.sh`, `scripts/build-game.sh`, `scripts/deploy.sh`, `scripts/auto-update.sh` | Build the game from your disc on a PC and copy it to the handheld (below). |
| `scripts/ci-host.sh SOURCE` | On aarch64 Linux: provisions the pinned toolchain, builds the ShiftGlue translator, the runtime, the GPU plugin and the host tests, and runs the tests. |
| `.github/workflows/ci.yml` | Builds the sysroot, then runs `ci-host.sh` on GitHub's `ubuntu-24.04-arm` runner in a bare Fedora 44 (the base of ArmadaOS) with that sysroot, the cross build on x86-64, and packages the launcher. |
| `.github/workflows/sysroot.yml` | On demand: publishes the sysroot as release `sysroot-VERSION` and pins it in `sysroot.json`. |
| `.github/workflows/release.yml` | Publishes the launcher for an upstream release as release `vVERSION`. |
| `.github/workflows/upstream-check.yml` | Every Monday: if upstream has a newer release, runs the CI on it, then records it in `upstream.json` and publishes its launcher when green, or opens an issue when not. |

## How a release is made

1. `ci.yml` builds the ARM64 sysroot, then the translator, runtime, GPU
   plugin, FidelityFX library and the 11 host tests for aarch64 with the
   pinned LLVM: natively against the sysroot in a bare Fedora 44 (the base of
   ArmadaOS), and cross-compiled on x86-64. It also packages the launcher.
2. `sysroot.yml`, run by hand when the sysroot changes, publishes it as
   release `sysroot-VERSION` and pins it in `sysroot.json`.
3. `release.yml` publishes the launcher for the upstream release in
   `upstream.json` as release `vVERSION`. Every Monday `upstream-check.yml`
   tries the newest upstream release and runs it when CI is green.

The launcher a release ships checks this repository for updates, and
downloads the sysroot, LLVM, CMake and Ninja into
`~/.local/share/PinyonShift` on first use. On ARM64 its **Play** starts the
game with the Android build's Adreno and Turnip defaults (patch 0006,
described in the patched `docs/LINUX_ARM64.md`).

## Building the game without the launcher

### On an x86-64 PC (Windows with WSL, or Ubuntu)

The PC translates the game and cross-compiles it for ARM64; the handheld only
receives the finished game. In an Ubuntu 24.04 WSL distribution:

```bash
git clone https://github.com/Ken5998/pinyon-shift-arm64 ~/pinyon-shift-arm64
cd ~/pinyon-shift-arm64
scripts/wsl-setup.sh                                   # once: arm64 packages, cross GCC
scripts/build-game.sh --iso /mnt/c/path/to/forza-horizon.iso
scripts/deploy.sh user@retroid                         # rsync over SSH, keeps saves
```

The first build needs about 45 GB in WSL. The pinned toolchain is kept in
`~/pinyon-shift-arm64-work/toolchain` and reused by later releases.
`build-game.sh` stages the game in `~/pinyon-shift-arm64-work/device/PinyonShift`;
without SSH on the handheld, copy that folder to `~/PinyonShift` on it.

**Automatic updates.** `scripts/auto-update.sh` pulls this repository and,
when `upstream.json` names a release the PC has not built yet (the weekly CI
moves it only after a green ARM64 build), builds and deploys it. Write
`~/pinyon-shift-arm64-work/auto-update.conf`:

```bash
ISO=/mnt/c/path/to/forza-horizon.iso
DEVICE=user@retroid
```

and run it daily from the Windows Task Scheduler:

```text
wsl.exe -d Ubuntu-24.04 -- bash -lc "~/pinyon-shift-arm64/scripts/auto-update.sh"
```

A local scheduled task is used instead of a self-hosted GitHub runner: on a
public repository, a self-hosted runner can be made to run code from other
people's pull requests.

### On the handheld, from a terminal

`prepare-source.sh` pins the sysroot, so setup needs nothing else on the
system:

```bash
scripts/prepare-source.sh ~/PinyonShift
cd ~/PinyonShift
python3 tools/pinyon.py setup --iso /path/to/your/forza-horizon.iso
```

### Playing

On the handheld, outside any distrobox:

```bash
cd ~/PinyonShift
python3 tools/pinyon.py launch
python3 tools/pinyon.py shortcuts add      # menu entry and Steam shortcut
```
