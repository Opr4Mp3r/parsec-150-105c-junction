param([int]$Run = 1)
$ErrorActionPreference = 'SilentlyContinue'
$log = "C:\p\vt\logs\run$Run-cleanup.log"
$prof = 'C:\Users\lowpriv\AppData\Roaming\Parsec'
$vbak = 'C:\Users\lowpriv\AppData\Roaming\Parsec.vbak'
$t = "C:\p\vt\run$Run"
$arch = "C:\p\vt\archive\run$Run"
"=== vt_cleanup run=$Run $(Get-Date -Format o) ===" | Out-File $log -Encoding ascii
sc.exe stop Parsec | Out-Null
for ($i=0; $i -lt 10; $i++) { Start-Sleep -Seconds 1; if ((Get-Service Parsec).Status -eq 'Stopped') { break } }
Get-Process parsecd -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Get-Process parsecd -ErrorAction SilentlyContinue | Stop-Process -Force
"service=" + (Get-Service Parsec).Status + " procs=" + ((Get-Process parsecd -ErrorAction SilentlyContinue | Measure-Object).Count) | Out-File $log -Append -Encoding ascii
$it = Get-Item -LiteralPath $prof -Force
if ($it -and (([string]$it.LinkType) -like '*Junction*')) {
    cmd /c rmdir "$prof" 2>&1 | Out-File $log -Append -Encoding ascii
    Start-Sleep -Milliseconds 300
    if (Test-Path -LiteralPath $vbak) { cmd /c move "$vbak" "$prof" 2>&1 | Out-File $log -Append -Encoding ascii }
}
$it2 = Get-Item -LiteralPath $prof -Force
"profile link=$([string]$it2.LinkType) target=$($it2.Target) json=" + (Test-Path "$prof\appdata.json") | Out-File $log -Append -Encoding ascii
"vbak_exists=" + (Test-Path -LiteralPath $vbak) | Out-File $log -Append -Encoding ascii
New-Item -ItemType Directory -Force -Path 'C:\p\vt\archive' | Out-Null
if (Test-Path -LiteralPath $arch) { cmd /c rmdir /s /q "$arch" 2>&1 | Out-File $log -Append -Encoding ascii }
if (Test-Path -LiteralPath $t) {
    cmd /c move "$t" "$arch" 2>&1 | Out-File $log -Append -Encoding ascii
    if (Test-Path -LiteralPath $arch) {
        "archived=$arch count=" + ((Get-ChildItem -LiteralPath $arch -Force | Measure-Object).Count) | Out-File $log -Append -Encoding ascii
        Get-ChildItem -LiteralPath $arch -Force | ForEach-Object { $a = Get-Acl -LiteralPath $_.FullName; "ARCH $($_.Name) len=$($_.Length) owner=$($a.Owner)" } | Out-File $log -Append -Encoding ascii
    } else { "ARCHIVE FAILED" | Out-File $log -Append -Encoding ascii }
}
"=== end ===" | Out-File $log -Append -Encoding ascii
Get-Content $log | Out-String