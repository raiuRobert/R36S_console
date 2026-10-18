"""Print the partition table of a raw disk image (MBR or GPT) and where the last partition ends.

Usage: python -I img_info.py <image.img> [card-size-bytes]
"""
import os
import struct
import sys

SECTOR = 512
MBR_TYPES = {0x0B: "FAT32", 0x0C: "FAT32 LBA", 0x83: "Linux", 0x07: "NTFS/exFAT", 0xEE: "GPT protective", 0x06: "FAT16", 0x0E: "FAT16 LBA"}


def main():
    path = sys.argv[1]
    card = int(sys.argv[2]) if len(sys.argv) > 2 else None
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        mbr = f.read(SECTOR)
        parts = []
        if mbr[510:512] != b"\x55\xaa":
            print("No MBR signature")
        for i in range(4):
            e = mbr[446 + 16 * i: 462 + 16 * i]
            ptype, start, count = e[4], *struct.unpack("<II", e[8:16])
            if ptype:
                parts.append((f"MBR{i + 1}", MBR_TYPES.get(ptype, hex(ptype)), start, count))
        if any(p[1] == "GPT protective" for p in parts):
            f.seek(SECTOR)
            hdr = f.read(SECTOR)
            entries_lba, n, esize = struct.unpack("<QII", hdr[72:88])
            f.seek(entries_lba * SECTOR)
            parts = []
            for i in range(n):
                e = f.read(esize)
                first, last = struct.unpack("<QQ", e[32:48])
                if first:
                    name = e[56:128].decode("utf-16-le").rstrip("\x00")
                    parts.append((f"GPT{i + 1}", name, first, last - first + 1))
        # Rockchip / Allwinner boot code markers
        f.seek(8192)
        egon = f.read(16)
        f.seek(64 * SECTOR)
        rk = f.read(4)

    print(f"image size: {size:,} bytes")
    print(f"boot code: Allwinner eGON at 8K: {b'eGON' in egon} | Rockchip idbloader at 32K: {rk!r}")
    end = 0
    for name, kind, start, count in parts:
        stop = (start + count) * SECTOR
        end = max(end, stop)
        print(f"  {name:6} {kind:16} start {start * SECTOR:>15,}  size {count * SECTOR:>15,}  ends {stop:>15,}")
    print(f"last partition ends at: {end:,} bytes ({(size - end) / 2**20:.1f} MiB unused at the end of the image)")
    if card:
        verdict = "FITS" if end <= card else "DOES NOT FIT"
        print(f"card size: {card:,} bytes -> partitions {verdict} ({(card - end) / 2**20:+.1f} MiB spare)")


if __name__ == "__main__":
    main()
