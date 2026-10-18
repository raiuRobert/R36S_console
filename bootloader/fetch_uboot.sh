#!/bin/bash
# Fetch the newest stable mainline U-Boot release into WSL's own filesystem (~/src/u-boot).
# Building on /mnt/d is slow, so the source lives inside Ubuntu; outputs are copied back later.
set -euo pipefail

REPO=https://source.denx.de/u-boot/u-boot.git
tag=$(git ls-remote --tags --refs "$REPO" 'v20*' | awk -F/ '{print $3}' | grep -v rc | sort -V | tail -1)
echo "latest stable U-Boot: $tag"

mkdir -p ~/src
cd ~/src
rm -rf u-boot
git clone -q --depth 1 --branch "$tag" "$REPO" u-boot
cd u-boot
git log -1 --format='%h %cd %s'
echo "A23/A33 board configs:"
grep -lE 'CONFIG_MACH_SUN8I_A(23|33)=y' configs/* | xargs -n1 basename
