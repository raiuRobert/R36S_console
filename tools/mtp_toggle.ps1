# Disable (default) or re-enable the console's MTP interface in Windows (goodluckOS gadget
# VID_1D6B&PID_0104, interface MI_02). Needs an elevated PowerShell. Result: logs\mtp_toggle.log
# Usage: powershell -ExecutionPolicy Bypass -File mtp_toggle.ps1 [disable|enable]
param([string]$Action = 'disable')
$log = Join-Path $PSScriptRoot '..\logs\mtp_toggle.log'
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Action" | Out-File -Append -Encoding utf8 $log
$devs = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match '^USB\\VID_1D6B&PID_0104&MI_02\\' }
if (-not $devs) { 'no MTP interface of the console found (connect it and retry)' | Out-File -Append -Encoding utf8 $log; exit 1 }
# The console's USB connection can drop every few seconds, so retry for up to 90 s.
foreach ($d in $devs) {
    $end = (Get-Date).AddSeconds(90); $done = $false
    while (-not $done -and (Get-Date) -lt $end) {
        try {
            if ($Action -eq 'enable') { Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop }
            else { Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop }
            "$Action OK: $($d.InstanceId)" | Out-File -Append -Encoding utf8 $log; $done = $true
        } catch { $err = $_.Exception.Message; Start-Sleep -Milliseconds 700 }
    }
    if (-not $done) { "$Action FAILED: $($d.InstanceId): $err" | Out-File -Append -Encoding utf8 $log }
}
Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VID_1D6B&PID_0104' } |
    ForEach-Object { "$($_.Status) $($_.Class) $($_.FriendlyName) $($_.InstanceId)" } | Out-File -Append -Encoding utf8 $log
