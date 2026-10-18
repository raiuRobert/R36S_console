#!/bin/sh
# Root boot hook, run at boot (as root, in the background) by /etc/init.d/S00ga36log.
# Forces the OTG USB gadget to full speed (12 Mbit/s): at high speed the PC resets the link every
# 2-8 s (logs/usbdebug). Clears HSENAB (0x20) in the MUSB POWER register (0x01c19040) and does a
# soft reconnect (SOFTCONN 0x40 off/on), so the PC enumerates the console again at full speed.
# Then logs the USB state for 120 s to check that the resets are gone.
U=/sys/class/udc/musb-hdrc.2.auto
POWER=0x01c19040
up() { cut -d' ' -f1 /proc/uptime; }
echo "=== root hook start, uptime $(up), id $(id -u)"

i=0
while [ "$(cat $U/state 2>/dev/null)" != configured ] && [ $i -lt 120 ]; do sleep 0.5; i=$((i + 1)); done
echo "$(up) udc=$(cat $U/state 2>/dev/null) speed=$(cat $U/current_speed 2>/dev/null)"

v=$(devmem $POWER 8) || { echo "devmem read failed"; exit 1; }
echo "POWER before: $v"
nv=$(( v & 0x9f ))
devmem $POWER 8 $nv
sleep 1
devmem $POWER 8 $(( nv | 0x40 ))
sleep 3
echo "$(up) POWER after: $(devmem $POWER 8) udc=$(cat $U/state) speed=$(cat $U/current_speed)"
sync

last=""
end=$(( $(cut -d. -f1 /proc/uptime) + 120 ))
while [ "$(cut -d. -f1 /proc/uptime)" -lt "$end" ]; do
    s="udc=$(cat $U/state 2>/dev/null) speed=$(cat $U/current_speed 2>/dev/null) POWER=$(devmem $POWER 8)"
    [ "$s" != "$last" ] && { echo "$(up) $s"; last=$s; }
    sleep 0.2
done
echo "=== end, uptime $(up)"
