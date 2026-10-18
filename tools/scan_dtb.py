"""Read-only scan of a raw disk for device tree blobs (magic D0 0D FE ED)."""
import os, re, struct, sys

disk = sys.argv[1] if len(sys.argv) > 1 else r"\\.\PhysicalDrive3"
scan_mb = int(sys.argv[2]) if len(sys.argv) > 2 else 2048
out_dir = sys.argv[3] if len(sys.argv) > 3 else "."
os.makedirs(out_dir, exist_ok=True)

CHUNK = 8 * 1024 * 1024
MAGIC = b"\xd0\x0d\xfe\xed"
KEYS = re.compile(rb"rk3326|odroid|anbernic|r3[56]|rg351|gameconsole|powkiddy|panel|evb|rf35|k36|clone", re.I)

found = []
with open(disk, "rb", buffering=0) as f:
    pos = 0
    prev_tail = b""
    while pos < scan_mb * 1024 * 1024:
        data = f.read(CHUNK)
        if not data:
            break
        buf = prev_tail + data
        base = pos - len(prev_tail)
        i = buf.find(MAGIC)
        while i != -1:
            if i + 40 <= len(buf):
                total, off_struct, off_strings = struct.unpack(">III", buf[i + 4:i + 16])
                if 1000 < total < 2 * 1024 * 1024 and off_struct < total and off_strings < total:
                    found.append((base + i, total))
            i = buf.find(MAGIC, i + 1)
        prev_tail = data[-64:]
        pos += len(data)
    print(f"Scanned {pos // (1024 * 1024)} MB, candidates: {len(found)}")

    seen = set()
    for k, (off, size) in enumerate(found):
        if off in seen:
            continue
        seen.add(off)
        start = off - off % 512
        f.seek(start)
        raw = f.read(((size + (off - start)) // 512 + 1) * 512)
        blob = raw[off - start:off - start + size]
        strs = sorted({m.group().decode() for m in re.finditer(rb"[\x20-\x7e]{5,}", blob) if KEYS.search(m.group())})
        name = os.path.join(out_dir, f"dtb_{k}_{off:X}.dtb")
        with open(name, "wb") as o:
            o.write(blob)
        print(f"[{k}] offset=0x{off:X} size={size} -> {name}")
        print("    " + " | ".join(strs[:15]))
