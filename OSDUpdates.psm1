Set-StrictMode -Version Latest

function Get-OSDUpdateTarget {
    [CmdletBinding()]
    param([string]$WindowsPath)
    if (-not $WindowsPath) {
        $candidates = @(
            Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
                $root = "$($_.DriveLetter):\"
                if (Test-Path -LiteralPath (Join-Path $root 'Windows\System32\Config\SYSTEM')) { $root }
            }
        )
        if ($candidates.Count -ne 1) { throw "Expected one offline Windows volume; found $($candidates.Count). Specify -WindowsPath." }
        $WindowsPath = $candidates[0]
    }
    $resolvedPath = [System.IO.Path]::GetFullPath($WindowsPath)
    if ([System.IO.Path]::GetFileName($resolvedPath.TrimEnd('\')) -ieq 'Windows') {
        $resolvedPath = [System.IO.Path]::GetPathRoot($resolvedPath)
    }
    $rootPath = [System.IO.Path]::GetPathRoot($resolvedPath)
    $windowsDir = Join-Path $rootPath 'Windows'
    if (-not (Test-Path -LiteralPath (Join-Path $windowsDir 'System32\Config\SYSTEM'))) {
        throw "No offline Windows installation found at $windowsDir"
    }
    $letter = $rootPath.Substring(0,1)
    if ($letter -eq 'X') { throw 'WinPE X: cannot be a servicing target.' }
    if ($env:SystemDrive -and $rootPath.TrimEnd('\') -ieq $env:SystemDrive -and -not (Test-Path 'X:\Windows\System32\startnet.cmd')) {
        throw 'Refusing to service the running Windows installation. Boot into WinPE.'
    }
    $partition = Get-Partition -DriveLetter $letter -ErrorAction Stop
    $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
    if ($disk.PartitionStyle -ne 'GPT') { throw 'Only GPT/UEFI disks are supported by this initial version.' }
    $efi = @(Get-Partition -DiskNumber $partition.DiskNumber | Where-Object {
        $_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -or $_.Type -eq 'System'
    })
    [pscustomobject]@{
        WindowsRoot = $rootPath
        WindowsDirectory = $windowsDir
        DiskNumber = $partition.DiskNumber
        WindowsPartitionNumber = $partition.PartitionNumber
        EfiPartitions = $efi
    }
}

function Test-OSDUpdateCache {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$UpdatePath)
    if (-not (Test-Path -LiteralPath $UpdatePath -PathType Container)) { throw "Update folder not found: $UpdatePath" }
    $files = @(Get-ChildItem -LiteralPath $UpdatePath -Filter '*.msu' -File)
    if ($files.Count -eq 0) { throw "No MSU files in $UpdatePath" }
    foreach ($file in $files) {
        [pscustomobject]@{
            Name = $file.Name
            FullName = $file.FullName
            SizeBytes = $file.Length
            SHA256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
}

function Install-OSDUpdate {
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    param(
        [Parameter(Mandatory)][string]$UpdatePath,
        [Parameter(Mandatory)][string]$TargetMsu,
        [string]$WindowsPath,
        [switch]$SkipBootFiles
    )
    $target = Get-OSDUpdateTarget -WindowsPath $WindowsPath
    $updates = @(Test-OSDUpdateCache -UpdatePath $UpdatePath)
    $selected = @($updates | Where-Object Name -eq $TargetMsu)
    if ($selected.Count -ne 1) { throw "Target MSU '$TargetMsu' not found exactly once in $UpdatePath." }
    if (-not (Test-Path -LiteralPath 'X:\Windows\System32\startnet.cmd')) {
        throw 'Install-OSDUpdate requires WinPE. Refusing to perform offline servicing in a running Windows session.'
    }
    $imageRoot = $target.WindowsRoot
    $logRoot = Join-Path $imageRoot 'OSDUpdates-Logs'
    $scratch = Join-Path $logRoot 'Scratch'
    if (-not $PSCmdlet.ShouldProcess($imageRoot, "Install $TargetMsu and update UEFI boot files")) { return }
    New-Item -ItemType Directory -Path $scratch -Force -ErrorAction Stop | Out-Null
    $started = Get-Date
    $log = Join-Path $logRoot 'DISM.log'
    $dismArgs = @(
        "/Image:$imageRoot",'/Add-Package',
        "/PackagePath:$($selected[0].FullName)",
        "/ScratchDir:$scratch", "/LogPath:$log"
    )
    & dism.exe @dismArgs
    if ($LASTEXITCODE -ne 0) { throw "DISM failed with exit code $LASTEXITCODE. See $log" }
    if (-not $SkipBootFiles) {
        $efi = @($target.EfiPartitions)
        if ($efi.Count -ne 1) { throw "Expected one EFI partition on disk $($target.DiskNumber); found $($efi.Count). Run BCDBoot manually after inspection." }
        $part = $efi[0]
        $createdAccessPath = $false
        $efiLetter = $part.DriveLetter
        if (-not $efiLetter) {
            $used = @(Get-Volume | Where-Object DriveLetter | ForEach-Object { [string]$_.DriveLetter })
            $efiLetter = @('S','T','U','V','Y','Z' | Where-Object { $_ -notin $used } | Select-Object -First 1)[0]
            if (-not $efiLetter) { throw 'No safe temporary EFI drive letter available.' }
            Set-Partition -DiskNumber $target.DiskNumber -PartitionNumber $part.PartitionNumber -NewDriveLetter $efiLetter -ErrorAction Stop
            $createdAccessPath = $true
        }
        try {
            & bcdboot.exe $target.WindowsDirectory /s "$($efiLetter):" /f UEFI
            if ($LASTEXITCODE -ne 0) { throw "BCDBoot failed with exit code $LASTEXITCODE" }
        } finally {
            if ($createdAccessPath) {
                Remove-PartitionAccessPath -DiskNumber $target.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "$($efiLetter):\" -ErrorAction Stop
            }
        }
    }
    [pscustomobject]@{
        Success = $true
        WindowsRoot = $imageRoot
        Update = $TargetMsu
        DismLog = $log
        BootFilesUpdated = (-not $SkipBootFiles)
        RebootPerformed = $false
        DurationSeconds = [math]::Round(((Get-Date) - $started).TotalSeconds,1)
    }
}

Export-ModuleMember -Function Get-OSDUpdateTarget,Test-OSDUpdateCache,Install-OSDUpdate
