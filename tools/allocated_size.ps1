param([Parameter(Mandatory)] [string]$Path)
# Prints the bytes actually allocated on disk for a (possibly sparse) file — useful for tracking torrent progress.
Add-Type -Namespace Win32 -Name Disk -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint GetCompressedFileSizeW(string lpFileName, out uint lpFileSizeHigh);
'@
$high = [uint32]0
$low = [Win32.Disk]::GetCompressedFileSizeW($Path, [ref]$high)
[uint64]$high * 4294967296 + $low
