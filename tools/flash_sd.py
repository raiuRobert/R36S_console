"""Write a raw OS image to an SD card on Windows and verify it by reading it back.

Usage (from an Administrator terminal):
    python -I flash_sd.py <image.img> <disk-number> [resume-at-percent | sync]

sync compares the card with the image and rewrites only the 4 MiB chunks that differ.

resume-at-percent continues an interrupted write from that point (rounded down to a 4 MiB
boundary); the whole card is still compared against the image afterwards.

Safety checks: the target must be a removable USB/SD disk, not the boot/system disk,
between the image size and 256 GB. You must type the disk number again to confirm.
"""
import ctypes
import hashlib
import json
import os
import subprocess
import sys
import time
from ctypes import wintypes

CHUNK = 4 * 1024 * 1024
MAX_DISK = 256 * 10**9

GENERIC_READ, GENERIC_WRITE = 0x80000000, 0x40000000
FILE_SHARE_RW = 0x1 | 0x2
OPEN_EXISTING = 3
FILE_FLAG_NO_BUFFERING, FILE_FLAG_WRITE_THROUGH = 0x20000000, 0x80000000
FSCTL_LOCK_VOLUME, FSCTL_DISMOUNT_VOLUME = 0x90018, 0x90020
INVALID_HANDLE = wintypes.HANDLE(-1).value

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.CreateFileW.restype = wintypes.HANDLE
k32.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID,
                            wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
k32.DeviceIoControl.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPVOID, wintypes.DWORD,
                                wintypes.LPVOID, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
k32.WriteFile.argtypes = [wintypes.HANDLE, wintypes.LPCVOID, wintypes.DWORD,
                          ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
k32.ReadFile.argtypes = [wintypes.HANDLE, wintypes.LPVOID, wintypes.DWORD,
                         ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
k32.SetFilePointerEx.argtypes = [wintypes.HANDLE, ctypes.c_longlong, ctypes.c_void_p, wintypes.DWORD]
k32.CloseHandle.argtypes = [wintypes.HANDLE]


class Tee:
    """Mirror console output to a log file so the result can be read after an elevated run."""

    def __init__(self, stream, path):
        self.stream, self.log = stream, open(path, "a", encoding="utf-8")

    def write(self, s):
        self.stream.write(s)
        self.log.write(s)
        self.log.flush()

    def flush(self):
        self.stream.flush()


def die(msg):
    print(f"ERROR: {msg}")
    sys.exit(1)


def open_handle(path, access, flags=0):
    h = k32.CreateFileW(path, access, FILE_SHARE_RW, None, OPEN_EXISTING, flags, None)
    if h == INVALID_HANDLE:
        die(f"cannot open {path} (WinError {ctypes.get_last_error()}). Run this from an Administrator terminal.")
    return h


def ioctl(h, code):
    ret = wintypes.DWORD()
    return k32.DeviceIoControl(h, code, None, 0, None, 0, ctypes.byref(ret), None)


def sync_card(disk, image, size, base, done):
    """Make the card match the image: rewrite only differing chunks and re-read each one."""

    def read_at(pos, n):
        k32.SetFilePointerEx(disk, pos, None, 0)
        if not k32.ReadFile(disk, base, n, ctypes.byref(done), None) or done.value != n:
            die(f"read failed at {pos:,} (WinError {ctypes.get_last_error()})")
        return ctypes.string_at(base, n)

    fixed = []
    t0 = time.time()
    with open(image, "rb") as f:
        pos = 0
        while pos < size:
            data = f.read(CHUNK)
            n = len(data)
            if read_at(pos, n) != data:
                ctypes.memmove(base, data, n)
                k32.SetFilePointerEx(disk, pos, None, 0)
                if not k32.WriteFile(disk, base, n, ctypes.byref(done), None) or done.value != n:
                    die(f"write failed at {pos:,} (WinError {ctypes.get_last_error()})")
                if read_at(pos, n) != data:
                    die(f"VERIFY FAILED - chunk at byte {pos:,} still differs after rewriting (bad card?)")
                fixed.append(pos)
            pos += n
            if (pos // CHUNK) % 64 == 0 or pos == size:
                rate = pos / 1e6 / max(time.time() - t0, 0.1)
                print(f"\r  syncing {pos / size * 100:5.1f}%  {rate:5.1f} MB/s  rewritten chunks: {len(fixed)}",
                      end="", flush=True)
    print()
    for p in fixed:
        print(f"  rewrote 4 MiB chunk at byte {p:,}")
    print(f"OK - card matches the image ({len(fixed)} chunk(s) rewritten and re-checked). Eject it safely before removing.")


def disk_info(num):
    ps = (f"$d=Get-Disk -Number {num}; $l=@(Get-Partition -DiskNumber {num} -ErrorAction SilentlyContinue | "
          "Where-Object DriveLetter | ForEach-Object {[string]$_.DriveLetter}); "
          "[pscustomobject]@{Name=$d.FriendlyName;Bus=[string]$d.BusType;Size=$d.Size;"
          "Boot=$d.IsBoot;System=$d.IsSystem;Letters=$l} | ConvertTo-Json -Compress")
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True)
    if out.returncode != 0 or not out.stdout.strip():
        die(f"disk {num} not found: {out.stderr.strip()}")
    info = json.loads(out.stdout)
    letters = info.get("Letters") or []
    info["Letters"] = [letters] if isinstance(letters, str) else letters
    return info


def main():
    if len(sys.argv) not in (3, 4):
        die(__doc__)
    image, num = sys.argv[1], int(sys.argv[2])
    mode = sys.argv[3] if len(sys.argv) == 4 else "0"
    sync = mode == "sync"
    resume_pct = 0.0 if sync else float(mode)
    sys.stdout = Tee(sys.stdout, os.path.splitext(image)[0] + ".flash.log")
    print(f"=== flash_sd {time.strftime('%Y-%m-%d %H:%M:%S')} ===")
    size = os.path.getsize(image)
    if size % 512:
        die("image size is not a multiple of 512 bytes")

    info = disk_info(num)
    print(f"Target disk {num}: {info['Name']} | bus {info['Bus']} | {info['Size'] / 1e9:.2f} GB | "
          f"volumes {', '.join(l + ':' for l in info['Letters']) or 'none'}")
    print(f"Image: {image} ({size / 1e9:.2f} GB)")
    if info["Boot"] or info["System"]:
        die("target is the boot/system disk")
    if info["Bus"] not in ("USB", "SD", "MMC"):
        die(f"target bus is {info['Bus']}, expected USB/SD")
    if not (size <= info["Size"] <= MAX_DISK):
        die("target size is smaller than the image or larger than 256 GB")

    start = int(size * resume_pct / 100) // CHUNK * CHUNK
    if sync:
        print("Sync mode: compare every chunk, rewrite only the ones that differ, re-check each rewrite.")
    elif start:
        print(f"Resuming: writing from byte {start:,} ({start / size * 100:.1f}%); the whole card is verified afterwards.")

    if input(f"\nALL DATA on disk {num} will be erased. Type the disk number again to continue: ").strip() != str(num):
        die("cancelled")

    # Lock and dismount every mounted volume on the card so Windows lets us write raw sectors.
    vol_handles = []
    for letter in info["Letters"]:
        h = open_handle(f"\\\\.\\{letter}:", GENERIC_READ | GENERIC_WRITE)
        if not ioctl(h, FSCTL_LOCK_VOLUME):
            # Something (Explorer, indexer, antivirus) holds the volume open; a dismount without the
            # lock still forces it offline. The verify pass catches anything that slips through.
            print(f"warning: cannot lock {letter}: (in use) - forcing dismount instead")
        ioctl(h, FSCTL_DISMOUNT_VOLUME)
        vol_handles.append(h)

    disk = open_handle(f"\\\\.\\PhysicalDrive{num}", GENERIC_READ | GENERIC_WRITE,
                       FILE_FLAG_NO_BUFFERING | FILE_FLAG_WRITE_THROUGH)
    # NO_BUFFERING needs a sector-aligned buffer; use a page-aligned view into an oversized one.
    aligned = (ctypes.c_char * (CHUNK + 4096))()
    base = (ctypes.addressof(aligned) + 4095) & ~4095
    done = wintypes.DWORD()

    if sync:
        sync_card(disk, image, size, base, done)
        k32.CloseHandle(disk)
        for h in vol_handles:
            k32.CloseHandle(h)
        return

    t0 = time.time()
    with open(image, "rb") as f:
        pos = start
        f.seek(pos)
        k32.SetFilePointerEx(disk, pos, None, 0)
        while pos < size:
            data = f.read(CHUNK)
            ctypes.memmove(base, data, len(data))
            if not k32.WriteFile(disk, base, len(data), ctypes.byref(done), None) or done.value != len(data):
                die(f"write failed at {pos} (WinError {ctypes.get_last_error()})")
            pos += len(data)
            if (pos // CHUNK) % 64 == 0 or pos == size:
                rate = (pos - start) / 1e6 / max(time.time() - t0, 0.1)
                print(f"\r  writing {pos / size * 100:5.1f}%  {rate:5.1f} MB/s", end="", flush=True)
    print(f"\nWrite done in {time.time() - t0:.0f}s. Verifying the whole card against the image...")

    # Compare chunk by chunk (from offset 0, also covering any part written by an earlier run).
    k32.SetFilePointerEx(disk, 0, None, 0)
    src_hash, dst_hash = hashlib.sha1(), hashlib.sha1()
    with open(image, "rb") as f:
        pos = 0
        while pos < size:
            data = f.read(CHUNK)
            n = len(data)
            if not k32.ReadFile(disk, base, n, ctypes.byref(done), None) or done.value != n:
                die(f"read failed at {pos} (WinError {ctypes.get_last_error()})")
            card = ctypes.string_at(base, n)
            src_hash.update(data)
            dst_hash.update(card)
            if card != data:
                die(f"VERIFY FAILED - card differs from image in the chunk at byte {pos:,}")
            pos += n
            if (pos // CHUNK) % 64 == 0 or pos == size:
                print(f"\r  verifying {pos / size * 100:5.1f}%", end="", flush=True)
    print()

    k32.CloseHandle(disk)
    for h in vol_handles:
        k32.CloseHandle(h)

    print(f"image SHA1: {src_hash.hexdigest()}")
    print(f"card  SHA1: {dst_hash.hexdigest()}")
    if src_hash.digest() != dst_hash.digest():
        die("VERIFY FAILED - the card did not store the data correctly")
    print("OK - card written and verified. Eject it safely before removing.")


if __name__ == "__main__":
    main()
