"""Read a byte range from a raw SD card into a file (read-only).

Usage (Administrator terminal): python -I read_at.py <disk-number> <byte-offset> <length> <out-file>
Only removable USB/SD disks are accepted.
"""
import ctypes
import importlib.util
import os
import sys

_spec = importlib.util.spec_from_file_location("flash_sd", os.path.join(os.path.dirname(os.path.abspath(__file__)), "flash_sd.py"))
fs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fs)


def main():
    if len(sys.argv) != 5:
        fs.die(__doc__)
    num, offset, length, out = int(sys.argv[1]), int(sys.argv[2], 0), int(sys.argv[3], 0), sys.argv[4]
    if offset % 512 or length % 512:
        fs.die("offset and length must be multiples of 512")
    info = fs.disk_info(num)
    print(f"Disk {num}: {info['Name']} | bus {info['Bus']} | {info['Size'] / 1e9:.2f} GB")
    if info["Boot"] or info["System"] or info["Bus"] not in ("USB", "SD", "MMC"):
        fs.die("not a removable USB/SD disk")

    disk = fs.open_handle(f"\\\\.\\PhysicalDrive{num}", fs.GENERIC_READ, fs.FILE_FLAG_NO_BUFFERING)
    chunk = fs.CHUNK
    buf = (ctypes.c_char * (chunk + 4096))()
    base = (ctypes.addressof(buf) + 4095) & ~4095
    done = fs.wintypes.DWORD()
    fs.k32.SetFilePointerEx(disk, offset, None, 0)
    with open(out, "wb") as f:
        left = length
        while left:
            n = min(chunk, left)
            if not fs.k32.ReadFile(disk, base, n, ctypes.byref(done), None) or done.value != n:
                fs.die(f"read failed (WinError {ctypes.get_last_error()})")
            f.write(ctypes.string_at(base, n))
            left -= n
    fs.k32.CloseHandle(disk)
    print(f"read {length:,} bytes from offset {offset:,} into {out}")


if __name__ == "__main__":
    main()
