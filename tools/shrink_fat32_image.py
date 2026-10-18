"""Shrink a disk image whose LAST partition is FAT32 so it fits a smaller card.

Truncates the image to <target-bytes> and patches the MBR entry plus the FAT32 boot
sectors (primary + backup) and FSInfo. Refuses if any allocated cluster lies past the
new end. Modifies the image IN PLACE.

Usage: python -I shrink_fat32_image.py <image.img> <target-bytes>
"""
import os
import struct
import sys

SECTOR = 512


def die(msg):
    print(f"ERROR: {msg}")
    sys.exit(1)


def main():
    path, target = sys.argv[1], int(sys.argv[2])
    size = os.path.getsize(path)
    if target >= size:
        die("image already fits")
    if target % SECTOR:
        die("target must be a multiple of 512")

    with open(path, "r+b") as f:
        mbr = bytearray(f.read(SECTOR))
        # Find the MBR entry that ends last.
        entries = []
        for i in range(4):
            e = mbr[446 + 16 * i: 462 + 16 * i]
            start, count = struct.unpack("<II", e[8:16])
            if e[4]:
                entries.append((start + count, i, start, count))
        end, idx, pstart, _ = max(entries)
        if end * SECTOR != size:
            die("last partition does not end at the end of the image")

        f.seek(pstart * SECTOR)
        bs = bytearray(f.read(SECTOR))
        if bs[82:90] != b"FAT32   ":
            die("last partition is not FAT32")
        bps, spc, rsv, nfats = struct.unpack("<HBHB", bs[11:17])
        fatsz = struct.unpack("<I", bs[36:40])[0]
        fsinfo_sec, backup_sec = struct.unpack("<HH", bs[48:52])
        if bps != SECTOR:
            die("unexpected sector size")

        new_tot = target // SECTOR - pstart
        new_clusters = (new_tot - rsv - nfats * fatsz) // spc
        if new_clusters < 65525:
            die("too small for FAT32")

        f.seek((pstart + rsv) * SECTOR)
        fat = f.read(fatsz * SECTOR)
        last_used = max((c for c in range(2, len(fat) // 4) if struct.unpack_from("<I", fat, c * 4)[0] & 0x0FFFFFFF), default=0)
        if last_used >= new_clusters + 2:
            die(f"cluster {last_used} is in use beyond the new end (max {new_clusters + 1})")
        print(f"partition {idx + 1}: {struct.unpack('<I', bs[32:36])[0]} -> {new_tot} sectors, "
              f"clusters {new_clusters}, highest used {last_used}: OK")

        # Patch MBR partition length.
        struct.pack_into("<I", mbr, 446 + 16 * idx + 12, new_tot)
        f.seek(0)
        f.write(mbr)
        # Patch total sectors in primary and backup boot sectors.
        for sec in (0, backup_sec):
            f.seek((pstart + sec) * SECTOR)
            b = bytearray(f.read(SECTOR))
            struct.pack_into("<I", b, 32, new_tot)
            f.seek((pstart + sec) * SECTOR)
            f.write(b)
        # Mark free-cluster count unknown in FSInfo (primary + backup) so the OS recounts.
        for sec in (fsinfo_sec, backup_sec + fsinfo_sec):
            f.seek((pstart + sec) * SECTOR)
            fi = bytearray(f.read(SECTOR))
            if fi[0:4] == b"RRaA":
                struct.pack_into("<I", fi, 488, 0xFFFFFFFF)
                f.seek((pstart + sec) * SECTOR)
                f.write(fi)
        f.truncate(target)
    print(f"image truncated to {target:,} bytes")


if __name__ == "__main__":
    main()
