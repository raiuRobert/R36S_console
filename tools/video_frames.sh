#!/bin/bash
# Extract sample frames (for finding the screen) from a video, at the given times in seconds.
# Usage (WSL): bash video_frames.sh <video> <outdir> t1 [t2 ...]
set -euo pipefail
V=$1
OUT=$2
shift 2
mkdir -p "$OUT"
for t in "$@"; do
    ffmpeg -v error -y -ss "$t" -i "$V" -frames:v 1 -vf scale=512:-1 "$OUT/f_$t.jpg"
done
ls "$OUT"
