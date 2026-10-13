# pinyon-shift-arm64

Native ARM64 Linux support for [Pinyon Shift](https://github.com/arcanite24/pinyon-shift),
the ahead-of-time recompiled Xbox 360 *Forza Horizon*, aimed at Snapdragon
handhelds running [ArmadaOS](https://armadaos.dev/) such as the Retroid
Pocket 6.

This repository holds no game code and no Pinyon Shift sources: only patches
on top of upstream releases, scripts and CI. The game is always built from
your own disc, on your own machine, as upstream requires
([LEGAL.md](https://github.com/arcanite24/pinyon-shift/blob/main/docs/LEGAL.md)).

## What is here

| Path | What it does |
| --- | --- |
| `patches/` | The port: `linux-arm64` CMake presets and toolchain, ARM64 support in `tools/pinyon_setup.py` (native, and cross from x86-64 with `--target linux-arm64`), docs. Applied with `git am` on an upstream release. |
| `upstream.json` | The last upstream release the patches were verified on. |
| `scripts/prepare-source.sh DEST [TAG]` | Checks out an upstream release and applies the patches. |
| `scripts/wsl-setup.sh`, `scripts/build-game.sh`, `scripts/deploy.sh`, `scripts/auto-update.sh` | Build the game from your disc on a PC and copy it to the handheld (below). |
| `scripts/ci-host.sh SOURCE` | On aarch64 Linux: provisions the pinned toolchain, builds the ShiftGlue translator, the runtime, the GPU plugin and the host tests, and runs the tests. |
| `.github/workflows/ci.yml` | Runs the two scripts on GitHub's `ubuntu-24.04-arm` runner in Fedora 44, the base of ArmadaOS. |
| `.github/workflows/upstream-check.yml` | Every Monday: if upstream has a newer release, runs the CI on it, records it in `upstream.json` when green and opens an issue when not. |

## Status

- Verified: the translator, runtime, GPU plugin and the 11 host tests build
  for aarch64 with the pinned LLVM 20.1.8, and the tests pass.
- Not verified yet: a full game build and play session on a device.

## Building the game

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

### On the handheld

On ArmadaOS, in a `fedora-toolbox:44` distrobox with the packages listed in
`.github/workflows/ci.yml`:

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
BSD 3-Clause license. Neither grants any rights to *Forza Horizon* or Xbox
software.
