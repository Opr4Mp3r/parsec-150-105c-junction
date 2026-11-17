# Parsec for Windows 150-105c — Local Privilege Boundary Violation via `%APPDATA%\Parsec` Junction

**Researcher:** Opr4 · opr4mp3r@gmail.com · [github.com/Opr4Mp3r](https://github.com/Opr4Mp3r)
**Public disclosure:** 2026-11-17
**Vendor notified:** 2026-10-30 (security@parsec.app) — no response after 18 days
**CVE status:** requested via VulDB on 2026-11-17; no CVE assigned at publication time

---

## Summary

Parsec for Windows installs a LocalSystem service, `pservice.exe`, which accepts start requests from the per-user client `parsecd.exe` over the named pipe `\\.\pipe\PARSEC-NP`. For each request the service resolves the requesting user's Roaming profile path, injects it as `APPDATA` into a SYSTEM child process, and launches `parsecd.exe` with a copy of the winlogon token.

The service validates the Roaming root path itself for reparse points. It does not validate the `%APPDATA%\Parsec` subdirectory that the loader uses as its data directory. A standard user can move the real `%APPDATA%\Parsec` directory aside and replace it with a directory junction to an arbitrary target directory. Running the officially signed `parsecd.exe` then causes SYSTEM-side components to create or overwrite a fixed set of files in the target directory, and Parsec's directory-permission logic removes the target directory's `Everyone` ACE. The user does not need, and never obtains, write access to the target.

This is a local security-boundary violation — SYSTEM-side file creation/overwrite and DACL modification — not unsigned code execution. The loader's WinVerifyTrust check and Parsec public-key pin remain effective.

## Affected product

| Item | Value |
| --- | --- |
| Product | Parsec for Windows 150-105c (Unity Technologies / Parsec Cloud, Inc.) |
| Service | `pservice.exe` 150.104.0.0 — SHA-256 `566f3dfd079b1c3129aae68645f0005a869544078aa86b0a14864a36ad7aa9cf` |
| Client / loader | `parsecd.exe` 150.104a.0.0 — SHA-256 `e1181c0ee31fb49e19038081c111387fc70be880fa1e3a783e6ec62004c5b4e0` |
| Installer | `parsec-windows.exe`, 4,403,720 bytes — SHA-256 `b8a9cd519010666def0ef6e119eb42b33b5b811216f34e4f6c8e2e25ac290fbc` |
| Tested on | Windows 10 Pro 22H2, build 19045.6466, testsigning disabled, default UAC, Defender enabled |

Only 150-105c was tested. Builds that contain the same service/loader pair may also be affected.

> Note: `pservice.exe` has file version `150.104.0.0`. This is a file version, not an IP address. Some automated form processors mask it as `x.x.x.x`; the correct value is `150.104.0.0`.

## Root cause

1. The standard user moves `C:\Users\<user>\AppData\Roaming\Parsec` aside and creates a junction at that path pointing to a target directory the user cannot write to (for example `C:\p\vt\run1`).
2. The user runs `C:\Program Files\Parsec\parsecd.exe app_silent=1`. The process connects to `\\.\pipe\PARSEC-NP` and sends a START message.
3. `pservice.exe` validates the client image and signature, resolves the Roaming path from the client user's profile, injects it as `APPDATA`, and calls `CreateProcessAsUserW` with a SYSTEM token copied from winlogon (session 0).
4. The SYSTEM-side `parsecd.exe` loader selects `%APPDATA%\Parsec`, follows the junction, and creates `appdata.json`, `parsecd-150-103a.dll`, `config.json`, `config.txt`, `hotkey.json`, `lock`, `cc1.txt`, and `log.txt` in the target. Parsec's directory-permission logic removes the target's `Everyone:(OI)(CI)(RX)` ACE.

The service's reparse-point check (`FUN_140003740`, RVA `0x3740`) covers the Roaming root and rejects mount points (`0xA0000003`) and symlinks (`0xA000000C`). The `%APPDATA%\Parsec` subdirectory used by the loader (`FUN_1400059a0`, RVA `0x59a0`) is not covered.

## Impact

- A standard user can make a LocalSystem service create or overwrite a fixed set of files, including a Parsec-signed DLL, in an arbitrary directory the user cannot write to.
- The SYSTEM-side component removes the target directory's `Everyone` ACE, changing its access control without the user holding any permission on that directory.
- The user does not gain administrator rights, and unsigned code is not loaded: the loader performs WinVerifyTrust and pins Parsec's public key, and file names/content are not attacker-controlled.

CVSS 3.1: `AV:L/AC:L/PR:L/UI:N/S:C/C:N/I:H/A:L` — base score 7.3 (High). CWE-59, CWE-732.

## Evidence

- 5/5 positive runs produced eight files owned by `BUILTIN\Administrators` in a directory the standard user could not write to, and removed the `Everyone:(OI)(CI)(RX)` ACE.
- A negative control with the profile left as a real directory and no junction produced zero files and preserved the `Everyone` ACE.
- The standard user's write and mkdir probes were false before and after every run.
- The SYSTEM child ran in session 0 with `APPDATA=C:\Users\lowpriv\AppData\Roaming` and `USERPROFILE=C:\Windows\system32\config\systemprofile`.

The full report contains the logs, file hashes, ACL before/after, decompiled code, and the complete PoC source in Appendix A.

## Relation to CVE-2026-54424

CVE-2026-54424 (fixed in 150-104a) describes an earlier issue in the same product involving the UPDATE command and an arbitrary AppData path. This report is a distinct issue: the tested build is 150-105c; the trigger does not use UPDATE, does not set an arbitrary AppData path, does not inject into a process, and does not use UNC paths. The missing validation here is on the `%APPDATA%\Parsec` subdirectory. This is not presented as a bypass of CVE-2026-54424.

## Reproduction

- [Full technical report (PDF)](report/Parsec_150-105c_AppData_Junction_CVE_Report_EN.pdf)
- [PoC scripts and reproduction notes](poc/README-repro.md)
- [Reproduction video (115 s)](media/parsec-150-105c-junction-repro.mp4)

Run only on an isolated test VM. The junction changes the user's real `%APPDATA%\Parsec` path; the cleanup script restores it. Do not run against a production machine or a machine you do not own.

## Disclosure timeline

| Date | Event |
| --- | --- |
| 2026-07-04 | CVE-2026-54424 published (context; different issue). |
| 2026-10-21 | Issue discovered and verified in an isolated lab (5/5 positive, 1/1 negative control). |
| 2026-10-30 | Report sent to `security@parsec.app` with report, video, and PoC; no response. |
| 2026-11-17 | Public disclosure and CVE request via VulDB after 18 days without a vendor response. |

## CVE status

No CVE was assigned at publication time. A CVE request was submitted to VulDB (a CVE Numbering Authority) on 2026-11-17; the VulDB submission is **#1099246** (status: Received / Analysis). If a CVE is assigned, this README will be updated with the identifier.

## Credit

Opr4 — independent security researcher.

## Disclaimer

This material is published for defensive purposes, vendor remediation, and authorized security testing. Do not use it to attack systems you do not own or have explicit permission to test. The vendor was notified before publication; the report is published after the vendor did not respond.
