"""Write a small file to a raw SD card at a byte offset, back up what it replaces, verify by reading back.

Usage (Administrator terminal): python -I write_at.py <file> <disk-number> <byte-offset>
Same safety checks as flash_sd.py (removable USB/SD disk only, typed confirmation).
"""
import ctypes
import importlib.util
import os
import sys
import time

_spec = importlib.util.spec_from_file_location("flash_sd", os.path.join(os.path.dirname(os.path.abspath(__file__)), "flash_sd.py"))
fs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fs)


def main():
    if len(sys.argv) != 4:
        fs.die(__doc__)
    path, num, offset = sys.argv[1], int(sys.argv[2]), int(sys.argv[3], 0)
    data = open(path, "rb").read()
    if offset % 512 or len(data) % 512:
        fs.die("offset and file size must be multiples of 512")
    sys.stdout = fs.Tee(sys.stdout, os.path.splitext(path)[0] + ".write.log")
    print(f"=== write_at {time.strftime('%Y-%m-%d %H:%M:%S')} ===")

    info = fs.disk_info(num)
    print(f"Target disk {num}: {info['Name']} | bus {info['Bus']} | {info['Size'] / 1e9:.2f} GB | "
          f"volumes {', '.join(l + ':' for l in info['Letters']) or 'none'}")
    print(f"Writing {path} ({len(data)} bytes) at byte offset {offset:,}")
    if info["Boot"] or info["System"]:
        fs.die("target is the boot/system disk")
    if info["Bus"] not in ("USB", "SD", "MMC") or info["Size"] > fs.MAX_DISK:
        fs.die("target is not a removable USB/SD disk")
    if input(f"\nType the disk number again to write to disk {num}: ").strip() != str(num):
        fs.die("cancelled")

    vols = []
    for letter in info["Letters"]:
        h = fs.open_handle(f"\\\\.\\{letter}:", fs.GENERIC_READ | fs.GENERIC_WRITE)
        if not fs.ioctl(h, fs.FSCTL_LOCK_VOLUME):
            # Something (Explorer, indexer, antivirus) holds the volume open. A dismount without the
            # lock still forces it offline; small writes outside the partitions don't need the lock.
            print(f"warning: cannot lock {letter}: (in use) - forcing dismount instead")
        fs.ioctl(h, fs.FSCTL_DISMOUNT_VOLUME)
        vols.append(h)

    disk = fs.open_handle(f"\\\\.\\PhysicalDrive{num}", fs.GENERIC_READ | fs.GENERIC_WRITE,
                          fs.FILE_FLAG_NO_BUFFERING | fs.FILE_FLAG_WRITE_THROUGH)
    buf = (ctypes.c_char * (len(data) + 4096))()
    base = (ctypes.addressof(buf) + 4095) & ~4095
    done = fs.wintypes.DWORD()

    def io(write, payload=None):
        fs.k32.SetFilePointerEx(disk, offset, None, 0)
        if write:
            ctypes.memmove(base, payload, len(payload))
            ok = fs.k32.WriteFile(disk, base, len(payload), ctypes.byref(done), None)
        else:
            ok = fs.k32.ReadFile(disk, base, len(data), ctypes.byref(done), None)
        if not ok or done.value != len(data):
            fs.die(f"{'write' if write else 'read'} failed (WinError {ctypes.get_last_error()})")
        return ctypes.string_at(base, len(data))

    backup = os.path.splitext(path)[0] + f".disk{num}-at{offset}.{time.strftime('%Y%m%d-%H%M%S')}.backup.bin"
    open(backup, "wb").write(io(False))
    print(f"backed up the old bytes to {backup}")
    io(True, data)
    if io(False) != data:
        fs.die("VERIFY FAILED - read-back differs")
    fs.k32.CloseHandle(disk)
    for h in vols:
        fs.k32.CloseHandle(h)
    print("OK - written and verified.")


if __name__ == "__main__":
    main()
