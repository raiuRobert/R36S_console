#!/bin/sh
# GA36-MB USB debug logger. Started once by goodluckOS appctl via /home/player/autolaunch
# (as user player). For 150 s it samples the USB device controller and the AXP VBUS input
# 5x per second and logs every change to /home/player/ga36_usbdebug.log, plus a full status
# line every 2 s. The screen stays on the loading screen meanwhile; the menu starts afterwards.
rm -f /home/player/autolaunch
OUT=/home/player/ga36_usbdebug.log
U=$(ls -d /sys/class/udc/* 2>/dev/null | head -n 1)
P=/sys/class/power_supply/axp20x-usb
B=/sys/class/power_supply/axp20x-battery
up() { cut -d' ' -f1 /proc/uptime; }
{
    echo "=== usb debug start, uptime $(up), udc $U"
    for f in "$P"/*; do [ -f "$f" ] && echo "$f=$(cat "$f" 2>/dev/null)"; done
    for f in status current_now voltage_now constant_charge_current constant_charge_current_max; do
        echo "$B/$f=$(cat "$B/$f" 2>/dev/null)"
    done
    grep -iE 'musb|axp|usb|ehci|ohci' /proc/interrupts
} > "$OUT" 2>&1
sync
last=""; n=0
end=$(( $(cut -d. -f1 /proc/uptime) + 150 ))
while [ "$(cut -d. -f1 /proc/uptime)" -lt "$end" ]; do
    s="udc=$(cat "$U/state" 2>/dev/null) speed=$(cat "$U/current_speed" 2>/dev/null) vbus_online=$(cat "$P/online" 2>/dev/null) vbus_present=$(cat "$P/present" 2>/dev/null) umtprd=$(pidof umtprd) getty_gs0=$(pgrep -f 'getty -L ttyGS0' 2>/dev/null | tr '\n' ' ')"
    if [ "$s" != "$last" ]; then echo "$(up) CHANGE $s" >> "$OUT"; last=$s; fi
    n=$((n + 1))
    if [ $((n % 10)) -eq 0 ]; then
        echo "$(up) status vbus_uV=$(cat "$P/voltage_now" 2>/dev/null) vbus_uA=$(cat "$P/current_now" 2>/dev/null) ilim=$(cat "$P/input_current_limit" 2>/dev/null) bat=$(cat "$B/status" 2>/dev/null) bat_uA=$(cat "$B/current_now" 2>/dev/null) bat_uV=$(cat "$B/voltage_now" 2>/dev/null) irq=$(grep -i musb /proc/interrupts | tr -s ' ' | cut -d' ' -f2-3)" >> "$OUT"
        sync
    fi
    sleep 0.2
done
{ echo "=== end, uptime $(up)"; grep -iE 'musb|axp|usb' /proc/interrupts; echo "--- dmesg (if allowed)"; dmesg 2>&1 | tail -80; } >> "$OUT" 2>&1
sync
