# Elevated, one time: hand the SD card reader to WSL (usbipd), install the root boot hook into the
# card's goodluckOS rootfs (partition 1), give the reader back to Windows. (wsl --mount refuses
# USB card readers.) Log: logs\install_root_hook.log
$log = Join-Path $PSScriptRoot '..\logs\install_root_hook.log'
$usbipd = 'C:\Program Files\usbipd-win\usbipd.exe'
function Log($s) { $s | Out-File -Append -Encoding utf8 $log; $s }
Log "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') install root hook (usbipd)"
$line = & $usbipd list | Select-String '14cd:121f' | Select-Object -First 1
if (-not $line) { Log 'card reader 14cd:121f not found'; Start-Sleep 5; exit 1 }
$busid = ($line.ToString().Trim() -split '\s+')[0]
Log "card reader busid $busid"
Get-Partition -DiskNumber 3 -ErrorAction SilentlyContinue | Where-Object DriveLetter | ForEach-Object {
    Write-VolumeCache -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue; Log "flushed $($_.DriveLetter):" }
Log ((& $usbipd bind --busid $busid 2>&1 | Out-String))
Log ((& $usbipd attach --wsl --busid $busid 2>&1 | Out-String))
$out = & wsl.exe -d Ubuntu-24.04 -u root -- bash /mnt/d/dev/R36s_console/bootloader/install_root_hook_usbip.sh 2>&1
Log (($out | Out-String) -replace "`0", '')
Log ((& $usbipd detach --busid $busid 2>&1 | Out-String))
Log ((& $usbipd unbind --busid $busid 2>&1 | Out-String))
Log '=== done'
Start-Sleep -Seconds 3
