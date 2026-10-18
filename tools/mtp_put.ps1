# Copy local files to the root of the console's MTP storage (goodluckOS HOME), retrying while the
# USB connection comes and goes. Usage: powershell -NoProfile -ExecutionPolicy Bypass -File mtp_put.ps1 <seconds> <file>...
param([int]$Seconds = 90, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)
$shell = New-Object -ComObject Shell.Application
$end = (Get-Date).AddSeconds($Seconds)
$done = @{}
while ((Get-Date) -lt $end -and $done.Count -lt $Files.Count) {
    try {
        $dev = $shell.NameSpace(17).Items() | Where-Object { $_.Name -match 'GA36|goodluck|MTP USB Device' } | Select-Object -First 1
        if ($dev) {
            $storage = $dev.GetFolder.Items() | Select-Object -First 1
            $folder = $storage.GetFolder
            foreach ($f in $Files) {
                if ($done[$f]) { continue }
                $name = Split-Path $f -Leaf
                $folder.CopyHere((Resolve-Path $f).Path, 4 + 16 + 1024)
                Start-Sleep -Seconds 2
                $item = $folder.Items() | Where-Object { $_.Name -eq $name -or $_.Name -eq [IO.Path]::GetFileNameWithoutExtension($name) }
                if ($item) { $done[$f] = $true; "$(Get-Date -Format HH:mm:ss) put $name (device size $($item.Size))" }
            }
        }
    } catch { "$(Get-Date -Format HH:mm:ss) error: $($_.Exception.Message)" }
    Start-Sleep -Milliseconds 500
}
"done: $($done.Count)/$($Files.Count)"
