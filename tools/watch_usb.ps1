# Watch for the console on USB: FEL (VID_1F3A) or goodluckOS's gadget (VID_1D6B&PID_0104: ACM serial + MTP).
# Logs every change to logs\usb_watch.log. Usage: powershell -NoProfile -ExecutionPolicy Bypass -File watch_usb.ps1 [minutes]
param([int]$Minutes = 15)
$log = Join-Path $PSScriptRoot '..\logs\usb_watch.log'
"=== usb watch $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') for $Minutes min ===" | Out-File -Append -Encoding utf8 $log
$last = ''
$end = (Get-Date).AddMinutes($Minutes)
while ((Get-Date) -lt $end) {
    $devs = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -match 'VID_1D6B&PID_0104|VID_1F3A|USB\\VID_0000&PID_0002' } |
        ForEach-Object { "$($_.Class) | $($_.FriendlyName) | $($_.Status) | $($_.InstanceId)" } | Sort-Object
    $now = ($devs -join "`n")
    if ($now -ne $last) {
        "--- $(Get-Date -Format HH:mm:ss)" | Out-File -Append -Encoding utf8 $log
        if ($now) { $now | Out-File -Append -Encoding utf8 $log } else { '(none)' | Out-File -Append -Encoding utf8 $log }
        $ports = Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue | ForEach-Object { "$($_.DeviceID) $($_.Name) $($_.PNPDeviceID)" }
        if ($ports) { "COM ports: $($ports -join '; ')" | Out-File -Append -Encoding utf8 $log }
        $last = $now
    }
    Start-Sleep -Seconds 2
}
"=== watch ended $(Get-Date -Format HH:mm:ss)" | Out-File -Append -Encoding utf8 $log
