param([int]$Run = 1)
$ErrorActionPreference = 'SilentlyContinue'
$log = "C:\p\vt\logs\run$Run-postprobe.log"
$t = "C:\p\vt\run$Run"
"=== postprobe run=$Run $(Get-Date -Format o) user=$env:USERNAME ===" | Out-File $log -Encoding ascii
$probe = "$t\lowpriv_probe_after.txt"
New-Item -ItemType File -Path $probe -Force -ErrorAction SilentlyContinue | Out-Null
$allowed = Test-Path -LiteralPath $probe
"target_write_after=$allowed" | Out-File $log -Append -Encoding ascii
if ($allowed) { Remove-Item -LiteralPath $probe -Force }
New-Item -ItemType Directory -Path "$t\lowpriv_dir_after" -Force -ErrorAction SilentlyContinue | Out-Null
$dirAllowed = Test-Path -LiteralPath "$t\lowpriv_dir_after"
"target_mkdir_after=$dirAllowed" | Out-File $log -Append -Encoding ascii
if ($dirAllowed) { cmd /c rmdir "$t\lowpriv_dir_after" 2>&1 | Out-Null }
"read_appdata=" + (Test-Path -LiteralPath "$t\appdata.json") | Out-File $log -Append -Encoding ascii
"=== end ===" | Out-File $log -Append -Encoding ascii
Get-Content $log | Out-String