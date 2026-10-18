# Copy files from the console's MTP storage (goodluckOS HOME) to a local folder, retrying while the
# USB connection comes and goes. Usage: powershell -NoProfile -ExecutionPolicy Bypass -File mtp_grab.ps1 <dest> [pattern] [seconds]
param([string]$Dest, [string]$Pattern = 'ga36_linux_*.log', [int]$Seconds = 90)
New-Item -ItemType Directory -Force $Dest | Out-Null
$shell = New-Object -ComObject Shell.Application
$end = (Get-Date).AddSeconds($Seconds)
$got = @{}
while ((Get-Date) -lt $end) {
    try {
        $pc = $shell.NameSpace(17)
        $dev = $pc.Items() | Where-Object { $_.Name -match 'GA36|goodluck|MTP USB Device' } | Select-Object -First 1
        if ($dev) {
            foreach ($storage in $dev.GetFolder.Items()) {
                foreach ($f in $storage.GetFolder.Items()) {
                    if ($f.Name -like $Pattern -or ($f.Name + '.log') -like $Pattern) {
                        if (-not $got[$f.Name]) {
                            $shell.NameSpace((Resolve-Path $Dest).Path).CopyHere($f, 4 + 16 + 1024)
                            Start-Sleep -Seconds 2
                            $local = Get-ChildItem $Dest | Where-Object { $_.BaseName -eq [IO.Path]::GetFileNameWithoutExtension($f.Name) -or $_.Name -eq $f.Name }
                            if ($local) { $got[$f.Name] = $true; "$(Get-Date -Format HH:mm:ss) copied $($f.Name) ($($local.Length) bytes)" }
                        }
                    }
                }
                if ($got.Count -eq 0) { "$(Get-Date -Format HH:mm:ss) storage '$($storage.Name)': $(@($storage.GetFolder.Items() | ForEach-Object { $_.Name }) -join ', ')" }
            }
            if ($got.Count -ge 3) { break }
        }
    } catch { "$(Get-Date -Format HH:mm:ss) error: $($_.Exception.Message)" }
    Start-Sleep -Milliseconds 500
}
"done: $($got.Keys -join ', ')"
