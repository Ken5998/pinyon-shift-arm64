# pinyon-shift-arm64

Native ARM64 Linux support for [Pinyon Shift](https://github.com/arcanite24/pinyon-shift),
the ahead-of-time recompiled Xbox 360 *Forza Horizon*, aimed at Snapdragon
handhelds running [ArmadaOS](https://armadaos.dev/) such as the Retroid
Pocket 6.

This repository holds no game code and no Pinyon Shift sources: only patches
on top of upstream releases, scripts and CI. Its releases hold a Linux ARM64
launcher, like upstream's launchers for Windows, Linux and macOS, and the
ARM64 sysroot it builds with. The game is always built from your own disc, on
your own machine, as upstream requires
([LEGAL.md](https://github.com/arcanite24/pinyon-shift/blob/main/docs/LEGAL.md)).

## Quick start on the handheld

1. On the handheld, in Desktop Mode, download
   `PinyonShift-Launcher-linux-arm64.tar.gz` from the
   [latest release](https://github.com/Ken5998/pinyon-shift-arm64/releases/latest).
2. Unpack it and start `PinyonShift/PinyonShiftLauncher`.
3. Choose your ISO of the USA retail disc (`MS-2505`) and keep the device on
   its charger while it builds. The first build needs about 35 GB free.
4. **Play**. **Add to Steam** adds a Steam shortcut; starting it from Gaming Mode on
   ArmadaOS, where Steam runs under FEX, is not verified yet.

The launcher downloads LLVM, CMake, Ninja and the ARM64 sysroot into
`~/.local/share/PinyonShift`, so nothing is installed on the system; the
device needs only `git` and Python 3.11 or newer. When a new upstream release
passes the weekly check, it is published here and the launcher offers it.

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

## Status

- Verified: the translator, runtime, GPU plugin and the 11 host tests build
  for aarch64 with the pinned LLVM 20.1.8, natively against the sysroot in a
  bare Fedora 44 and cross-compiled on x86-64, and the tests pass.
- On a Retroid Pocket 6 (ArmadaOS): the launcher builds the game on the
  handheld in under half an hour and it plays, at about 20 fps with
  LOW-SPEC 60 before the Android build's Adreno defaults were added.
- Not verified yet: the frame rate with those defaults, and launching from
  Steam's Gaming Mode.

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
python3 tools/pinyon.py launch -- --vulkan_texture_memory_prealloc_mb=256
python3 tools/pinyon.py shortcuts add      # menu entry and Steam shortcut
```

## License

BSD 3-Clause, as upstream. The patches modify upstream files under their
BSD 3-Clause license. The sysroot holds Ubuntu packages under their own
licences, listed in it. None of this grants any rights to *Forza Horizon* or
Xbox software.
