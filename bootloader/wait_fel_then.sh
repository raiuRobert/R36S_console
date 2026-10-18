#!/bin/bash
# Wait (up to 10 min) until the console answers in FEL mode, then run the given script.
# Usage (root, WSL): bash wait_fel_then.sh fel_diag.sh [args...]
HERE=$(cd "$(dirname "$0")" && pwd)
for i in $(seq 1 300); do
    if lsusb -d 1f3a:efe8 >/dev/null && timeout 3 sunxi-fel version >/dev/null 2>&1; then
        echo "FEL ready after ~$((i * 2))s"
        exec bash "$HERE/$1" "${@:2}"
    fi
    sleep 2
done
echo "FEL device never answered within 10 minutes"
exit 3
