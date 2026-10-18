"""Turn a phone video of the console into a backlight on/off timeline.

Usage (WSL, needs ffmpeg + numpy): python3 backlight_timeline.py <video> [width]
Decodes the (rotated) video at a small size, measures the mean blue level of the screen centre
relative to the white case below it (cancels the phone's auto-exposure), and prints the
on/off segments with their durations.
"""
import subprocess
import sys

import numpy as np

V = sys.argv[1]
W = int(sys.argv[2]) if len(sys.argv) > 2 else 128

probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                        "stream=r_frame_rate", "-of", "csv=p=0", V], capture_output=True, text=True).stdout
num, den = probe.strip().split(",")[0].split("/")
fps = float(num) / float(den)

# ffmpeg applies the rotation metadata, so frames come out portrait. Get the real output size
# from one decoded PNG frame (IHDR width/height at bytes 16..24).
png = subprocess.run(["ffmpeg", "-v", "error", "-i", V, "-vf", f"scale={W}:-2", "-frames:v", "1",
                      "-f", "image2pipe", "-vcodec", "png", "-"], capture_output=True).stdout
H = int.from_bytes(png[20:24], "big")
assert int.from_bytes(png[16:20], "big") == W
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", V, "-vf", f"scale={W}:-2", "-f", "rawvideo",
                      "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
frames = np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3).astype(np.float32)
n = len(frames)

# Regions as fractions of the frame (from the sample frames): screen centre and the white case.
def region(fx0, fy0, fx1, fy1):
    return frames[:, int(fy0 * H):int(fy1 * H), int(fx0 * W):int(fx1 * W), :]

screen = region(0.30, 0.27, 0.70, 0.46)
case = region(0.42, 0.53, 0.58, 0.57)
blue = screen[..., 2].mean(axis=(1, 2)) - screen[..., 0].mean(axis=(1, 2))  # blue tint of the backlight
level = screen.mean(axis=(1, 2, 3)) / np.maximum(case.mean(axis=(1, 2, 3)), 1)
sig = blue + 100 * level
lo, hi = np.percentile(sig, 10), np.percentile(sig, 90)
thr = (lo + hi) / 2
on = sig > thr

print(f"{n} frames, {fps:.2f} fps, {n / fps:.1f} s, frame {W}x{H}, threshold {thr:.1f} (p10 {lo:.1f}, p90 {hi:.1f})")
start = 0
for i in range(1, n + 1):
    if i == n or on[i] != on[start]:
        dur = (i - start) / fps
        print(f"{start / fps:6.2f}s  {'ON ' if on[start] else 'off'}  {dur:5.2f}s")
        start = i
