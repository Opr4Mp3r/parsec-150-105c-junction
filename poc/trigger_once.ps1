$ErrorActionPreference = 'SilentlyContinue'
$out = 'C:\p\logs\trigger_once.log'
"=== trigger_once $(Get-Date -Format o) ===" | Out-File $out -Encoding ascii
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'C:\Program Files\Parsec\parsecd.exe'
$psi.Arguments = 'app_silent=1'
$psi.UseShellExecute = $false
$psi.EnvironmentVariables['APPDATA'] = 'C:\p\fakeappdata'
$client = [System.Diagnostics.Process]::Start($psi)
"client pid=$($client.Id) at $(Get-Date -Format HH:mm:ss.fff)" | Out-File $out -Append -Encoding ascii
Start-Sleep -Seconds 3
"client hasExited=$($client.HasExited)" | Out-File $out -Append -Encoding ascii
"=== end ===" | Out-File $out -Append -Encoding ascii