#!/usr/bin/env bash
# One-time setup of an Ubuntu 24.04 machine (WSL included) to build the game
# for ARM64 handhelds: the arm64 architecture, the aarch64 cross compiler and
# the arm64 development packages the game links against. Needs sudo.
set -euo pipefail

. /etc/os-release
if [ "${ID:-}" != "ubuntu" ]; then
    echo "error: this script is for Ubuntu (found ${PRETTY_NAME:-unknown})" >&2
    exit 1
fi
codename="${VERSION_CODENAME:?}"

sudo dpkg --add-architecture arm64

# Ubuntu serves arm64 from ports.ubuntu.com, not from the amd64 mirrors:
# pin the existing sources to amd64 and add a ports source for arm64.
sources=/etc/apt/sources.list.d/ubuntu.sources
if [ -f "$sources" ] && ! grep -q '^Architectures:' "$sources"; then
    sudo sed -i 's/^\(Types: deb.*\)$/\1\nArchitectures: amd64/' "$sources"
fi
if [ -f /etc/apt/sources.list ]; then
    sudo sed -i -E 's/^deb (http|https|mirror)/deb [arch=amd64] \1/' /etc/apt/sources.list
fi
sudo tee /etc/apt/sources.list.d/ubuntu-ports-arm64.sources > /dev/null <<SOURCES
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports
Suites: $codename $codename-updates $codename-security
Components: main universe
Architectures: arm64
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES

# arm64 and amd64 copies of a library must have the same version, and ports
# carries security updates as soon as they are out. A mirror (Azure's, on
# GitHub's runners) can lag behind it, so amd64 takes them from the source.
sudo tee /etc/apt/sources.list.d/ubuntu-security-amd64.sources > /dev/null <<SOURCES
Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: $codename-security
Components: main universe
Architectures: amd64
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES

sudo apt-get update
arm64=(libx11-dev libx11-xcb-dev libxcb1-dev libxext-dev libxcursor-dev libxi-dev
       libxrandr-dev libxss-dev libxfixes-dev libxtst-dev libxkbcommon-dev libwayland-dev
       libdecor-0-dev libegl-dev libgl-dev libgles-dev libdrm-dev libgbm-dev
       libasound2-dev libpulse-dev libpipewire-0.3-dev libudev-dev libdbus-1-dev)
sudo apt-get install -y git python3 rsync xz-utils unzip pkg-config \
    g++-14-aarch64-linux-gnu libwayland-bin wayland-protocols \
    "${arm64[@]/%/:arm64}"
echo "Ready to build for ARM64."
