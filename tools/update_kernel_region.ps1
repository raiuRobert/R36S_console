# Elevated: re-enable the console's MTP device in Windows, then write the falcon kernel region
# (DTB copy at 2 MiB + uImage at 4 MiB) to the SD card, disk 3. Leaves rootfs/HOME (your setup) untouched.
& "$PSScriptRoot\mtp_toggle.ps1" enable
Get-Content "$PSScriptRoot\..\logs\mtp_toggle.log" -Tail 4
& 'C:\msys64\mingw64\bin\python.exe' -I "$PSScriptRoot\write_at.py" "$PSScriptRoot\..\bootloader\out\falcon_kernel_region_panel2.bin" 3 0x200000
Read-Host 'Done - press Enter to close'
