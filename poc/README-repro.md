# PoC Reproduction Notes — Parsec 150-105c

These are the six scripts reproduced in Appendix A of the English report. They were
verified on 2026-10-21 on Windows 10 Pro 22H2 (19045.6466), testsigning disabled,
with the standard user `WINLAB\lowpriv`.

Place all scripts in a directory readable by the standard user. The paths below
assume `C:\p\`.

## Role split

- Administrator: `vt_setup_admin.ps1`, `vt_check_admin.ps1`, `vt_cleanup_admin.ps1`
- Standard user `WINLAB\lowpriv`: `vt_junction_lowpriv.ps1`, `trigger_once.ps1`,
  `vt_postprobe_lowpriv.ps1`

## Sequence (one run)

```powershell
# Administrator
powershell -ExecutionPolicy Bypass -File C:\p\vt_setup_admin.ps1 -Run 1

# Standard user
powershell -ExecutionPolicy Bypass -File C:\p\vt_junction_lowpriv.ps1 -Run 1

# Administrator
sc start Parsec

# Standard user
powershell -ExecutionPolicy Bypass -File C:\p\trigger_once.ps1

# Administrator
powershell -ExecutionPolicy Bypass -File C:\p\vt_check_admin.ps1 -Run 1 -WaitSec 20

# Standard user
powershell -ExecutionPolicy Bypass -File C:\p\vt_postprobe_lowpriv.ps1 -Run 1

# Administrator
powershell -ExecutionPolicy Bypass -File C:\p\vt_cleanup_admin.ps1 -Run 1
```

Negative control: run `vt_setup_admin.ps1 -Negative` and
`vt_junction_lowpriv.ps1 -Negative` (the profile stays a real directory, no junction),
then perform the same start, trigger, and check steps. Expect `file_count=0` and
`everyone_ace_after=True`.

## Expected result

After one standard-user trigger:

- `file_count=8`, including `appdata.json` and `parsecd-150-103a.dll`
- `files_with_admin_or_system_owner=8` (owner `BUILTIN\Administrators`)
- `everyone_ace_after=False` (the target's `Everyone:(OI)(CI)(RX)` ACE is removed)
- `target_write_before=False` and `target_write_after=False`
- a session-0 `NT AUTHORITY\SYSTEM` `parsecd.exe` with
  `APPDATA=C:\Users\lowpriv\AppData\Roaming`

## Note on readenv.ps1

The original check script calls `C:\p\readenv.ps1` only to dump the SYSTEM child's
PEB environment (APPDATA, CWD, USERPROFILE). That helper is not included here; the
file count, owner, and ACL results do not depend on it. If it is absent, the check
log simply omits the `--- env dump ---` section.

## Safety

Run this only on an isolated test VM. The junction changes the user's real
`%APPDATA%\Parsec` path; the cleanup script restores it. Do not run on a production
machine or against a machine you do not own.
