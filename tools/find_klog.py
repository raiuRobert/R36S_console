"""Search a raw DRAM dump for Linux kernel log text (printk ring buffer contents).

Usage: python -I find_klog.py <dump.bin> [out.txt]
Prints the messages found around "Linux version", panics, oopses and errors, and writes all
readable kernel-looking lines to out.txt (default: next to the dump).
"""
import os
import re
import sys

KEYS = [b"Linux version", b"Kernel panic", b"Oops", b"Unable to", b"Internal error", b"PC is at",
        b"VFS:", b"Rebooting", b"reboot", b"Kernel command line", b"Booting Linux", b"Machine model",
        b"watchdog", b"BUG:", b"rcu:", b"error", b"failed", b"Run /sbin/init", b"Freeing unused"]


def main():
    path = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(path)[0] + ".klog.txt"
    data = open(path, "rb").read()
    runs = [(m.start(), m.group()) for m in re.finditer(rb"[\x20-\x7e\t]{12,}", data)]
    hits = [(off, s) for off, s in runs if any(k in s for k in KEYS)]
    print(f"{len(data):,} bytes scanned, {len(runs):,} text runs, {len(hits)} interesting")
    seen = set()
    for off, s in hits:
        t = s.decode(errors="replace")
        if t in seen:
            continue
        seen.add(t)
        print(f"{off:#010x}: {t[:200]}")
    with open(out, "w", encoding="utf-8") as f:
        for off, s in runs:
            f.write(f"{off:#010x}: {s.decode(errors='replace')}\n")
    print(f"all text runs written to {out}")


if __name__ == "__main__":
    main()
