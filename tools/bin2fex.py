"""Decode an Allwinner legacy script.bin (sys_config) found inside a disk image into .fex text.

Usage: python -I bin2fex.py <image-or-script.bin> <byte-offset> <out.fex>
"""
import struct
import sys

PORTS = " ABCDEFGHIJKLMN"


def main():
    path, base, out = sys.argv[1], int(sys.argv[2], 0), sys.argv[3]
    with open(path, "rb") as f:
        f.seek(base)
        blob = f.read(512 * 1024)
    count, *ver = struct.unpack_from("<4I", blob, 0)
    if not 0 < count < 512:
        sys.exit(f"implausible section count {count} at {base:#x}")
    lines = [f"; decoded from {path} @ {base:#x}, version {ver}"]
    for s in range(count):
        name, n, off = struct.unpack_from("<32sII", blob, 16 + s * 40)
        lines.append(f"\n[{name.rstrip(b'\0').decode(errors='replace')}]")
        for e in range(n):
            ename, eoff, pattern = struct.unpack_from("<32sII", blob, off * 4 + e * 40)
            key = ename.rstrip(b"\0").decode(errors="replace")
            typ, words = pattern >> 16, pattern & 0xFFFF
            data = blob[eoff * 4: eoff * 4 + words * 4]
            if typ == 1:
                val = str(struct.unpack_from("<i", data)[0])
            elif typ == 2:
                val = '"' + data.rstrip(b"\0").decode(errors="replace") + '"'
            elif typ == 4:
                port, num, mul, pull, drv, dat = struct.unpack_from("<6i", data)
                fmt = lambda v: "<default>" if v == -1 else str(v)
                val = f"port:P{PORTS[port] if 0 <= port < len(PORTS) else '?'}{num:02d}<{fmt(mul)}><{fmt(pull)}><{fmt(drv)}><{fmt(dat)}>"
            elif typ == 0:
                val = ""
            else:
                val = f"<type {typ}> " + data.hex()
            lines.append(f"{key} = {val}")
    with open(out, "w", encoding="utf-8") as o:
        o.write("\n".join(lines) + "\n")
    print(f"{count} sections -> {out}")


if __name__ == "__main__":
    main()
