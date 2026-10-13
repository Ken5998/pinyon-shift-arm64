#!/usr/bin/env bash
# Packages the Linux ARM64 launcher, as upstream packages its x86-64 one: the
# launcher and the patched source payload, without any game files.
#
#   scripts/package-launcher.sh SOURCE OUTDIR   (SOURCE made by prepare-source.sh)
#
# Needs the .NET 8 SDK; it cross-publishes for linux-arm64 from any host. The
# payload's config/release.json names this repository, so the launcher looks
# for updates in its releases. Writes OUTDIR/PinyonShift-Launcher-linux-arm64.tar.gz.
set -euo pipefail

src="$(cd "$1" && pwd)"
out="$(mkdir -p "$2" && cd "$2" && pwd)"
repository="https://github.com/${GITHUB_REPOSITORY:-Ken5998/pinyon-shift-arm64}"

python3 - "$src/config/release.json" "$repository" <<'PY'
import json, sys
path, repository = sys.argv[1:]
release = json.load(open(path, encoding="utf-8"))
release["repository"] = repository
open(path, "w", encoding="utf-8").write(json.dumps(release, indent=2) + "\n")
PY
if ! git -C "$src" diff --quiet -- config/release.json; then
    git -C "$src" -c user.name=pinyon-shift-arm64 -c user.email=pinyon-shift-arm64@users.noreply.github.com \
        commit -q -m "chore: take launcher updates from $repository" -- config/release.json
fi

python3 "$src/tools/package-launcher.py" --platform linux-arm64
cp "$src/.artifacts/PinyonShift-Launcher-linux-arm64.tar.gz" "$out/"
tar -tzvf "$out/PinyonShift-Launcher-linux-arm64.tar.gz"
