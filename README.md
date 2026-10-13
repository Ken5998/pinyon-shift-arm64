# pinyon-shift-arm64

Play [Pinyon Shift](https://github.com/arcanite24/pinyon-shift), the
ahead-of-time recompiled Xbox 360 *Forza Horizon*, natively on Snapdragon
handhelds running [ArmadaOS](https://armadaos.dev/), such as the Retroid
Pocket 6.

<p align="center">
  <img src="docs/launcher-setup.png" alt="The launcher before the first build: choose your Forza Horizon disc image, confirm you own it, then Verify and build" width="49%">
  <img src="docs/launcher-ready.png" alt="The launcher after the build: Play, Add to Steam and Rebuild" width="49%">
</p>

Like upstream's own launchers, this one builds the game on the handheld from
your own disc. This repository holds no game code
([LEGAL.md](https://github.com/arcanite24/pinyon-shift/blob/main/docs/LEGAL.md)).

## Install

You need an ISO of your USA retail disc (`MS-2505`) and about 35 GB free.

1. In **Desktop Mode**, download `PinyonShift-Launcher-linux-arm64.tar.gz`
   from the [latest release](https://github.com/Ken5998/pinyon-shift-arm64/releases/latest),
   extract it to your home folder and start `PinyonShift/PinyonShiftLauncher`.
2. **Choose disc image**, confirm that you own it and press **Verify and
   build**. Keep the handheld on its charger: the build takes 25 to 60
   minutes. *Copying the game files* can stay at 0.0 GB for a few minutes
   before it starts counting.
3. Press **Play**, or **Add to Steam** to start the game from Gaming Mode like
   any other game.

The launcher keeps everything in `~/.local/share/PinyonShift` and installs
nothing on the system. When a new Pinyon Shift release passes this
repository's weekly check, the launcher offers the update.

## In game

- **Select + Start** (or **F6**) opens the settings menu.
- Pressing **both sticks** (or **F3**) shows the performance panel.

## Settings for the Retroid Pocket 6

With these, the Retroid Pocket 6 runs at about 34 fps racing in traffic and 40
to 50 fps driving alone.

- ArmadaOS power profile: **Balanced** (Eco stays around 30 fps).
- In **settings > GRAPHICS**:
  - **GRAPHICS PRESET**: LOW-SPEC 60, with **RESOLUTION SCALE** 1X
  - **SHADOWS**: off
  - **SINGLE-PASS SCENE**: on
  - **REFLECTION UPDATES**: QUARTER
  - **SCENE SHADING**: COARSE
  - **TEXTURE GAMMA**: FAST (applies at the next start)

These are the choices of the Android build's SMOOTH 60 preset on the same
chip. The game always draws at 1280×720 or more: a smaller window does not
make it faster.

## If something goes wrong

The launcher shows which step failed. Its **Logs** link opens the build or
game logs; attach them to an
[issue](https://github.com/Ken5998/pinyon-shift-arm64/issues).

## Developers

How the port works, building the game on a PC instead, and how releases are
made: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## License

BSD 3-Clause, as upstream. The patches modify upstream files under their
BSD 3-Clause license. The sysroot holds Ubuntu packages under their own
licences, listed in it. None of this grants any rights to *Forza Horizon* or
Xbox software.
