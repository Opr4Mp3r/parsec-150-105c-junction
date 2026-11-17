param([int]$Run = 1, [switch]$Negative)
$ErrorActionPreference = 'SilentlyContinue'
$log = "C:\p\vt\logs\run$Run-setup.log"
New-Item -ItemType Directory -Force -Path 'C:\p\vt\logs' | Out-Null
"=== vt_setup run=$Run negative=$([bool]$Negative) $(Get-Date -Format o) ===" | Out-File $log -Encoding ascii
# stop service and any parsecd
sc.exe stop Parsec | Out-Null
for ($i=0; $i -lt 10; $i++) { Start-Sleep -Seconds 1; if ((Get-Service Parsec).Status -eq 'Stopped') { break } }
Get-Process parsecd -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Get-Process parsecd -ErrorAction SilentlyContinue | Stop-Process -Force
"service=" + (Get-Service Parsec).Status + " procs=" + ((Get-Process parsecd -ErrorAction SilentlyContinue | Measure-Object).Count) | Out-File $log -Append -Encoding ascii
$prof = 'C:\Users\lowpriv\AppData\Roaming\Parsec'
$it = Get-Item -LiteralPath $prof -Force
if ($it -and (([string]$it.LinkType) -like '*Junction*')) { "ABORT: profile is still a junction" | Out-File $log -Append -Encoding ascii; Get-Content $log; return }
$t = "C:\p\vt\run$Run"
if (Test-Path -LiteralPath $t) { cmd /c rmdir /s /q "$t" 2>&1 | Out-File $log -Append -Encoding ascii }
New-Item -ItemType Directory -Path $t -Force | Out-Null
# protected ACL: SYSTEM/Administrators full, Everyone RX, no lowpriv ACE, no inheritance
icacls.exe $t /inheritance:r /grant '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-1-0:(OI)(CI)RX' 2>&1 | Out-File $log -Append -Encoding ascii
"--- target state before ---" | Out-File $log -Append -Encoding ascii
"target=$t" | Out-File $log -Append -Encoding ascii
(Get-Item -LiteralPath $t -Force).Attributes | Out-File $log -Append -Encoding ascii
icacls.exe $t 2>&1 | Out-File $log -Append -Encoding ascii
$acl = Get-Acl -LiteralPath $t
"owner=$($acl.Owner) sddl=$($acl.Sddl)" | Out-File $log -Append -Encoding ascii
"children=" + ((Get-ChildItem -LiteralPath $t -Force | Measure-Object).Count) | Out-File $log -Append -Encoding ascii
"profile link=$([string]$it.LinkType) target=$($it.Target) json=" + (Test-Path "$prof\appdata.json") | Out-File $log -Append -Encoding ascii
"=== end ===" | Out-File $log -Append -Encoding ascii
Get-Content $log | Out-String