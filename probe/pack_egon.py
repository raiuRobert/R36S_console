"""Turn a raw binary into a bootable Allwinner eGON.BT0 image (pad, length, checksum).

Usage: python -I pack_egon.py <in.bin> <out.egon>
"""
import struct
import sys

PAD = 8192          # BROM needs >= 512-byte padding; 8 KiB works for every boot medium
STAMP = 0x5F0A6C39  # checksum seed the BROM expects in the checksum field


def main():
    data = bytearray(open(sys.argv[1], "rb").read())
    if data[4:12] != b"eGON.BT0":
        sys.exit("input has no eGON.BT0 header at offset 4")
    data += b"\0" * (-len(data) % PAD)
    if len(data) > 24 * 1024:
        sys.exit(f"image is {len(data)} bytes; must stay <= 24 KiB to fit SRAM and not reach SD offset 32K")
    struct.pack_into("<II", data, 12, STAMP, len(data))
    checksum = sum(struct.unpack(f"<{len(data) // 4}I", data)) & 0xFFFFFFFF
    struct.pack_into("<I", data, 12, checksum)
    open(sys.argv[2], "wb").write(data)
    print(f"{sys.argv[2]}: {len(data)} bytes, checksum {checksum:#010x}")


if __name__ == "__main__":
    main()
