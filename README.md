# OSDUpdates

Independent PowerShell module for offline Windows servicing during deployments.

**Status: v0.1.0 experimental prototype — not production-ready.**

## Purpose

OSDUpdates installs a manually chosen Microsoft cumulative update MSU into an already-applied Windows installation using DISM. It runs independently of OSDCloud and OSDApps, and does not reboot.

## Requirements

- WinPE with PowerShell, Storage cmdlets, DISM and BCDBoot
- UEFI/GPT, exactly one applicable EFI partition on the same disk as Windows
- Local Microsoft-signed MSU files; any checkpoint MSUs required by the target LCU must be in the same folder
- Test hardware, a recoverable deployment and x64 Windows 11 for initial validation

## Example

After `Deploy-OSDCloud -PostAction Quit`:

```powershell
Import-Module E:\Modules\OSDUpdates\OSDUpdates.psd1
Get-OSDUpdateTarget
Test-OSDUpdateCache -UpdatePath 'E:\OSDUpdates'
Install-OSDUpdate -UpdatePath 'E:\OSDUpdates' -TargetMsu 'ACTUAL-TARGET-LCU.msu' -Confirm:$false
```

Replace paths and MSU filename as appropriate. `-WhatIf` allows reviewing the intended operation without servicing; `-SkipBootFiles` skips BCDBoot only when it will be handled separately.

## Initial features

- Offline Windows volume detection, with explicit `-WindowsPath` override
- MSU enumeration and SHA-256 reporting
- DISM offline servicing with scratch directory and persistent log on the offline Windows disk
- EFI partition detection on the same disk and BCDBoot refresh
- Cleanup of any temporary EFI drive-letter assignment
- No network, no automatic downloads, no OSDApps invocation, no restart

## Limitations

- The caller explicitly selects the target LCU filename; there is no automatic KB or dependency resolution.
- Checkpoint applicability, image architecture and Microsoft Authenticode signature are **not yet** automatically verified.
- Only single-GPT-disk / single-EFI scenarios are considered for initial validation.
- DISM success is not proof of successful first boot or Autopilot completion.
- Pester structure tests do not validate WinPE storage or DISM behavior.

Development roadmap: reliable update source/catalog selection, strong authenticity validation, caching, richer applicability checks, integration tests and eventual PowerShell Gallery publication.
