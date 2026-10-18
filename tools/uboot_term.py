"""Serial console for the R36S U-Boot USB console (USB ACM COM port).

Usage: python -I uboot_term.py [log-file] [command-file]
  - waits for a new USB serial COM port to appear, then opens it at 115200
  - prints everything received and appends it to the log file (default: logs/uboot_console.log)
  - lines typed here are sent to the console
  - lines appended to the command file (default: logs/uboot_commands.txt) are also sent, so
    another program can drive the console while this window stays open
Press Ctrl+C to quit.
"""
import os
import sys
import threading
import time

import serial
from serial.tools import list_ports

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "logs", "uboot_console.log")
CMDS = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "logs", "uboot_commands.txt")


def usb_serial_ports():
    return {p.device: p for p in list_ports.comports() if p.vid is not None}


def wait_for_port():
    before = set(usb_serial_ports())
    print(f"Waiting for a new USB COM port (already present: {sorted(before) or 'none'}) ...", flush=True)
    while True:
        now = usb_serial_ports()
        new = [d for d in now if d not in before]
        if new:
            p = now[new[0]]
            print(f"Found {p.device}: {p.description} (VID {p.vid:04X} PID {p.pid:04X})", flush=True)
            return p.device
        before &= set(now)          # forget ports that went away so a re-plug counts as new
        time.sleep(0.3)


def main():
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    open(CMDS, "a").close()
    while True:
        dev = wait_for_port()
        try:
            ser = serial.Serial(dev, 115200, timeout=0.1)
        except serial.SerialException as e:
            print(f"cannot open {dev}: {e}; retrying", flush=True)
            time.sleep(1)
            continue
        log = open(LOG, "a", encoding="utf-8", errors="replace")
        log.write(f"\n===== {time.strftime('%Y-%m-%d %H:%M:%S')} connected {dev} =====\n")
        log.flush()
        cmd_pos = os.path.getsize(CMDS)
        stop = threading.Event()

        def keyboard():
            for line in sys.stdin:
                if stop.is_set():
                    break
                try:
                    ser.write(line.rstrip("\r\n").encode() + b"\r")
                except serial.SerialException:
                    break

        threading.Thread(target=keyboard, daemon=True).start()
        try:
            while True:
                data = ser.read(4096)
                if data:
                    text = data.decode("utf-8", errors="replace")
                    sys.stdout.write(text)
                    sys.stdout.flush()
                    log.write(text)
                    log.flush()
                if os.path.getsize(CMDS) > cmd_pos:
                    with open(CMDS, "r", encoding="utf-8") as c:
                        c.seek(cmd_pos)
                        new = c.read()
                        cmd_pos = c.tell()
                    for line in new.splitlines():
                        ser.write(line.encode() + b"\r")
                        time.sleep(0.05)
        except (serial.SerialException, OSError) as e:
            print(f"\n[disconnected: {e}]", flush=True)
            log.write(f"\n===== disconnected =====\n")
            log.close()
            stop.set()
            try:
                ser.close()
            except Exception:
                pass


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
