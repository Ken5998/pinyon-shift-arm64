#!/usr/bin/env python3
"""Pins the ARM64 sysroot in a source tree made by prepare-source.sh.

  scripts/pin-sysroot.py SOURCE                  the release in sysroot.json
  scripts/pin-sysroot.py SOURCE --archive FILE   a sysroot built here (CI)

Writes posix.linux-arm64.sysroot in SOURCE/config/release-toolchain.json and
commits it in SOURCE, so setup downloads and checks the sysroot like the
other tools. With --archive the file also goes into SOURCE/.local/downloads,
where setup finds it without downloading. Without sysroot.json or --archive
nothing changes and the build uses the host's development files.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
REPOSITORY = os.environ.get("GITHUB_REPOSITORY", "Ken5998/pinyon-shift-arm64")
NAME = re.compile(r"^pinyon-arm64-sysroot-(?P<version>[0-9][0-9A-Za-z.]*)\.tar\.xz$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def release_url(version: str) -> str:
    return (f"https://github.com/{REPOSITORY}/releases/download/sysroot-{version}/"
            f"pinyon-arm64-sysroot-{version}.tar.xz")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", type=Path)
    parser.add_argument("--archive", type=Path, help="a sysroot archive made by build-sysroot.sh")
    args = parser.parse_args()
    source = args.source.resolve()

    if args.archive:
        match = NAME.match(args.archive.name)
        if not match:
            raise SystemExit(f"error: {args.archive.name} is not a build-sysroot.sh archive")
        pin = {"version": match["version"], "url": release_url(match["version"]),
               "sha256": sha256(args.archive)}
        downloads = source / ".local" / "downloads"
        downloads.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args.archive, downloads / args.archive.name)
    elif (HERE / "sysroot.json").is_file():
        pin = json.loads((HERE / "sysroot.json").read_text(encoding="utf-8"))
    else:
        print("No ARM64 sysroot pinned; the build uses the host's development files.")
        return 0

    config_path = source / "config" / "release-toolchain.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    config["posix"]["linux-arm64"]["sysroot"] = {
        "label": "the ARM64 sysroot (Ubuntu 24.04)",
        "version": pin["version"],
        "url": pin["url"],
        "sha256": pin["sha256"].upper(),
        "install_path": f".local/toolchain/arm64-sysroot-{pin['version']}",
        "executable": "",
    }
    config_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    subprocess.run(["git", "-C", str(source), "-c", "user.name=pinyon-shift-arm64",
                    "-c", "user.email=pinyon-shift-arm64@users.noreply.github.com",
                    "commit", "-q", "-m", f"chore: pin the arm64 sysroot {pin['version']}",
                    "--", "config/release-toolchain.json"], check=True)
    print(f"Pinned ARM64 sysroot {pin['version']} ({pin['sha256'][:12]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
