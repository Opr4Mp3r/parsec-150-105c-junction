param([int]$Run = 1, [int]$WaitSec = 20)
$ErrorActionPreference = 'SilentlyContinue'
$log = "C:\p\vt\logs\run$Run-check.log"
$t = "C:\p\vt\run$Run"
"=== vt_check run=$Run $(Get-Date -Format o) ===" | Out-File $log -Encoding ascii
"target=$t wait=$WaitSec" | Out-File $log -Append -Encoding ascii
$deadline = (Get-Date).AddSeconds($WaitSec)
$sawSys = $false
$envDumped = $false
$sysInfo = @()
while ((Get-Date) -lt $deadline) {
    $files = Get-ChildItem -LiteralPath $t -Force -ErrorAction SilentlyContinue
    $procs = Get-CimInstance Win32_Process -Filter "Name='parsecd.exe'" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.SessionId -eq 0) {
            $o = (Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction SilentlyContinue)
            $line = "pid=$($p.ProcessId) s=0 owner=$($o.Domain)\$($o.User) cmd=$($p.CommandLine)"
            if (-not ($sysInfo -contains $line)) { $sysInfo += $line; $sawSys = $true }
            if (-not $envDumped) {
                $envlog = "C:\p\vt\logs\run$Run-env-$($p.ProcessId).log"
                powershell -NoProfile -ExecutionPolicy Bypass -File C:\p\readenv.ps1 -TargetPid $p.ProcessId -Out $envlog | Out-Null
                if (Test-Path -LiteralPath $envlog) { $envDumped = $true }
            }
        }
    }
    if (($files | Measure-Object).Count -gt 0) { Start-Sleep -Milliseconds 1500; break }
    Start-Sleep -Milliseconds 400
}
Start-Sleep -Seconds 3
"--- system process observations ---" | Out-File $log -Append -Encoding ascii
$sysInfo | ForEach-Object { $_ | Out-File $log -Append -Encoding ascii }
if ($envDumped) {
    "--- env dump (APPDATA/CWD/USERPROFILE) ---" | Out-File $log -Append -Encoding ascii
    Get-ChildItem "C:\p\vt\logs\run$Run-env-*.log" -ErrorAction SilentlyContinue | ForEach-Object {
        Get-Content $_.FullName | Where-Object { $_ -match '^(CWD|Image|Cmd|APPDATA|USERPROFILE|USERNAME|NtQuery)' } | Out-File $log -Append -Encoding ascii
    }
}
"--- target listing after ---" | Out-File $log -Append -Encoding ascii
$files = Get-ChildItem -LiteralPath $t -Force -ErrorAction SilentlyContinue
$count = ($files | Measure-Object).Count
"file_count=$count" | Out-File $log -Append -Encoding ascii
foreach ($f in $files) {
    $a = Get-Acl -LiteralPath $f.FullName
    $h = ''
    if (-not $f.PSIsContainer) { $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash }
    "FILE name=$($f.Name) dir=$($f.PSIsContainer) len=$($f.Length) owner=$($a.Owner) sha256=$h cw=$($f.CreationTimeUtc.ToString('o')) mw=$($f.LastWriteTimeUtc.ToString('o'))" | Out-File $log -Append -Encoding ascii
}
"--- target ACL after ---" | Out-File $log -Append -Encoding ascii
icacls.exe $t 2>&1 | Out-File $log -Append -Encoding ascii
$acl = Get-Acl -LiteralPath $t
"owner=$($acl.Owner) sddl=$($acl.Sddl)" | Out-File $log -Append -Encoding ascii
$everyoneAfter = (icacls.exe $t 2>&1 | Select-String 'Everyone') -ne $null
"everyone_ace_after=$everyoneAfter" | Out-File $log -Append -Encoding ascii
"appdata_json=" + (Test-Path -LiteralPath "$t\appdata.json") | Out-File $log -Append -Encoding ascii
if (Test-Path -LiteralPath "$t\appdata.json") { "appdata_content=" + (Get-Content -LiteralPath "$t\appdata.json" -Raw) | Out-File $log -Append -Encoding ascii }
$sysowner = 0
foreach ($f in $files) { $a = Get-Acl -LiteralPath $f.FullName; if ($a.Owner -match 'Administrators|SYSTEM') { $sysowner++ } }
"files_with_admin_or_system_owner=$sysowner" | Out-File $log -Append -Encoding ascii
"=== end ===" | Out-File $log -Append -Encoding ascii
Get-Content $log | Out-String