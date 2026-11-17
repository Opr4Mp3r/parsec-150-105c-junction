param([int]$Run = 1, [switch]$Negative)
$ErrorActionPreference = 'SilentlyContinue'
$log = "C:\p\vt\logs\run$Run-junction.log"
"=== vt_junction run=$Run negative=$([bool]$Negative) $(Get-Date -Format o) user=$env:USERNAME ===" | Out-File $log -Encoding ascii
$t = "C:\p\vt\run$Run"
$prof = 'C:\Users\lowpriv\AppData\Roaming\Parsec'
$vbak = 'C:\Users\lowpriv\AppData\Roaming\Parsec.vbak'
whoami.exe /user 2>&1 | Out-File $log -Append -Encoding ascii
# lowpriv write attempt against protected target (must fail)
$probe = "$t\lowpriv_probe.txt"
New-Item -ItemType File -Path $probe -Force -ErrorAction SilentlyContinue | Out-Null
$allowed = Test-Path -LiteralPath $probe
"target_write_before=$allowed" | Out-File $log -Append -Encoding ascii
if ($allowed) { Remove-Item -LiteralPath $probe -Force }
# also try a subdirectory creation
New-Item -ItemType Directory -Path "$t\lowpriv_dir" -Force -ErrorAction SilentlyContinue | Out-Null
$dirAllowed = Test-Path -LiteralPath "$t\lowpriv_dir"
"target_mkdir_before=$dirAllowed" | Out-File $log -Append -Encoding ascii
if ($dirAllowed) { cmd /c rmdir "$t\lowpriv_dir" 2>&1 | Out-Null }
if (-not $Negative) {
    $it = Get-Item -LiteralPath $prof -Force
    "profile_before link=$([string]$it.LinkType) target=$($it.Target)" | Out-File $log -Append -Encoding ascii
    if (([string]$it.LinkType) -like '*Junction*') { "ABORT: profile already a junction" | Out-File $log -Append -Encoding ascii; Get-Content $log; return }
    if (Test-Path -LiteralPath $vbak) { cmd /c rmdir /s /q "$vbak" 2>&1 | Out-File $log -Append -Encoding ascii }
    cmd /c move "$prof" "$vbak" 2>&1 | Out-File $log -Append -Encoding ascii
    Start-Sleep -Milliseconds 300
    cmd /c mklink /J "$prof" "$t" 2>&1 | Out-File $log -Append -Encoding ascii
    $it2 = Get-Item -LiteralPath $prof -Force
    "profile_after link=$([string]$it2.LinkType) target=$($it2.Target)" | Out-File $log -Append -Encoding ascii
    "vbak_exists=" + (Test-Path -LiteralPath $vbak) | Out-File $log -Append -Encoding ascii
} else {
    "NEGATIVE CONTROL: profile left as real directory" | Out-File $log -Append -Encoding ascii
    $it = Get-Item -LiteralPath $prof -Force
    "profile_before link=$([string]$it.LinkType) json=" + (Test-Path "$prof\appdata.json") | Out-File $log -Append -Encoding ascii
}
"=== end ===" | Out-File $log -Append -Encoding ascii
Get-Content $log | Out-String