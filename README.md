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
| `patches/` | The port: `linux-arm64` CMake presets and toolchain, ARM64 support in `tools/pinyon_setup.py`, docs. Applied with `git am` on an upstream release. |
| `upstream.json` | The last upstream release the patches were verified on. |
| `scripts/prepare-source.sh DEST [TAG]` | Checks out an upstream release and applies the patches. |
| `scripts/ci-host.sh SOURCE` | On aarch64 Linux: provisions the pinned toolchain, builds the ShiftGlue translator, the runtime, the GPU plugin and the host tests, and runs the tests. |
| `.github/workflows/ci.yml` | Runs the two scripts on GitHub's `ubuntu-24.04-arm` runner in Fedora 44, the base of ArmadaOS. |
| `.github/workflows/upstream-check.yml` | Every Monday: if upstream has a newer release, runs the CI on it, records it in `upstream.json` when green and opens an issue when not. |

## Status

- Verified: the translator, runtime, GPU plugin and the 11 host tests build
  for aarch64 with the pinned LLVM 20.1.8, and the tests pass.
- Not verified yet: a full game build and play session on a device.

## Building the game

On an aarch64 Linux system with the development packages listed in
`.github/workflows/ci.yml` (on ArmadaOS, in a `fedora-toolbox:44` distrobox):

```bash
scripts/prepare-source.sh ~/PinyonShift
cd ~/PinyonShift
python3 tools/pinyon.py setup --iso /path/to/your/forza-horizon.iso
python3 tools/pinyon.py launch
```

Cross-compiling the game on an x86-64 PC (WSL included) for the handheld is
being worked on.

## License

BSD 3-Clause, as upstream. The patches modify upstream files under their
BSD 3-Clause license. Neither grants any rights to *Forza Horizon* or Xbox
software.
