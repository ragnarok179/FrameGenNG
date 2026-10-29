function Get-FrameGenNGRestorePointRoot {
    param([Parameter(Mandatory)][string]$UserRoot)
    return Join-Path (Get-FrameGenNGDataRoot -UserRoot $UserRoot) 'restore-points'
}

function Get-FrameGenNGSettingsSnapshot {
    param([Parameter(Mandatory)][string]$UserRoot)
    $path = Join-Path $UserRoot 'settings\settings.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [pscustomobject][ordered]@{ available = $false; path = $path }
    }
    $settings = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    return [pscustomobject][ordered]@{
        available = $true
        path = $path
        enabledExists = $settings.PSObject.Properties.Name -contains $script:SettingsEnabledKey
        enabled = if ($settings.PSObject.Properties.Name -contains $script:SettingsEnabledKey) { [bool]$settings.($script:SettingsEnabledKey) } else { $false }
        multiplierExists = $settings.PSObject.Properties.Name -contains $script:SettingsMultiplierKey
        multiplier = if ($settings.PSObject.Properties.Name -contains $script:SettingsMultiplierKey) { [int]$settings.($script:SettingsMultiplierKey) } else { 2 }
    }
}

function Get-FrameGenNGRestorePoints {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$UserRoot)

    $root = Get-FrameGenNGRestorePointRoot -UserRoot $UserRoot
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return @() }
    $points = foreach ($directory in Get-ChildItem -LiteralPath $root -Directory -Force) {
        $metadataPath = Join-Path $directory.FullName 'metadata.json'
        $packagePath = Join-Path $directory.FullName 'package.zip'
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf) -or -not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { continue }
        try {
            $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
            if ([int]$metadata.schemaVersion -ne $script:RestorePointSchemaVersion) { continue }
            $metadata | Add-Member -NotePropertyName path -NotePropertyValue $directory.FullName -Force
            $metadata | Add-Member -NotePropertyName packagePath -NotePropertyValue $packagePath -Force
            $metadata | Add-Member -NotePropertyName sizeBytes -NotePropertyValue ([long](Get-Item -LiteralPath $packagePath).Length) -Force
            $metadata
        } catch {
            # A damaged point is ignored instead of blocking the manager.
        }
    }
    return @($points | Sort-Object { [datetime]$_.createdAt } -Descending)
}

function Invoke-FrameGenNGRestorePointRetention {
    param([Parameter(Mandatory)][string]$UserRoot)

    $automatic = @(Get-FrameGenNGRestorePoints -UserRoot $UserRoot | Where-Object { [string]$_.kind -eq 'automatic' } | Sort-Object { [datetime]$_.createdAt } -Descending)
    foreach ($point in @($automatic | Select-Object -Skip $script:AutomaticRestorePointLimit)) {
        $path = [System.IO.Path]::GetFullPath([string]$point.path)
        $root = [System.IO.Path]::GetFullPath((Get-FrameGenNGRestorePointRoot -UserRoot $UserRoot)).TrimEnd('\')
        if ($path.StartsWith($root + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}

function New-FrameGenNGRestorePoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$UserRoot,
        [Parameter(Mandatory)][ValidateSet('before-install','before-repair','before-update','before-uninstall','before-restore','manual')][string]$Reason,
        [string]$Label,
        [string]$GameRoot,
        [string]$LauncherIni
    )

    Assert-BeamNGClosed
    $kind = if ($Reason -eq 'manual') { 'manual' } else { 'automatic' }
    if ($kind -eq 'manual') {
        $manualCount = @(Get-FrameGenNGRestorePoints -UserRoot $UserRoot | Where-Object { [string]$_.kind -eq 'manual' }).Count
        if ($manualCount -ge $script:ManualRestorePointLimit) {
            throw "The manual restore-point limit ($($script:ManualRestorePointLimit)) has been reached. Delete an older manual point first."
        }
    }

    $packageRoot = Get-FrameGenNGPackageRoot
    $id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $restoreRoot = Get-FrameGenNGRestorePointRoot -UserRoot $UserRoot
    $destination = Join-Path $restoreRoot $id
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    try {
        $packageZip = Join-Path $destination 'package.zip'
        Compress-Archive -LiteralPath $packageRoot -DestinationPath $packageZip -CompressionLevel Optimal
        $stateRecord = Read-FrameGenNGState -UserRoot $UserRoot -AllowBackup
        $installed = $null -ne $stateRecord
        $state = if ($installed) { $stateRecord.state } else { $null }
        $gameIdentity = $null
        if (-not [string]::IsNullOrWhiteSpace($GameRoot)) {
            try { $gameIdentity = Get-BeamNGIdentity -GameRoot $GameRoot -LauncherIni $LauncherIni } catch { $gameIdentity = $null }
        }
        $metadata = [pscustomobject][ordered]@{
            schemaVersion = $script:RestorePointSchemaVersion
            id = $id
            createdAt = (Get-Date).ToString('o')
            kind = $kind
            reason = $Reason
            label = if ([string]::IsNullOrWhiteSpace($Label)) { switch ($Reason) { 'before-install' { 'Before installation' } 'before-repair' { 'Before repair' } 'before-update' { 'Before update' } 'before-uninstall' { 'Before uninstall' } 'before-restore' { 'Before restore' } default { 'Manual restore point' } } } else { $Label.Trim() }
            version = Get-FrameGenNGVersion
            installed = $installed
            profile = if ($installed) { [string]$state.profile } else { $null }
            gameIdentity = $gameIdentity
            settings = Get-FrameGenNGSettingsSnapshot -UserRoot $UserRoot
            packageSha256 = (Get-FileHash -LiteralPath $packageZip -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        # Metadata is written last; readers ignore incomplete folders without it.
        Write-JsonFile -Value $metadata -Path (Join-Path $destination 'metadata.json') -Depth 20
        Invoke-FrameGenNGRestorePointRetention -UserRoot $UserRoot
        return @(Get-FrameGenNGRestorePoints -UserRoot $UserRoot | Where-Object { [string]$_.id -eq $id })[0]
    } catch {
        if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
        throw
    }
}

function Remove-FrameGenNGRestorePoint {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$UserRoot, [Parameter(Mandatory)][string]$Id)
    $point = @(Get-FrameGenNGRestorePoints -UserRoot $UserRoot | Where-Object { [string]$_.id -eq $Id }) | Select-Object -First 1
    if ($null -eq $point) { throw "Restore point not found: $Id" }
    $root = [System.IO.Path]::GetFullPath((Get-FrameGenNGRestorePointRoot -UserRoot $UserRoot)).TrimEnd('\')
    $path = [System.IO.Path]::GetFullPath([string]$point.path)
    if (-not $path.StartsWith($root + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe restore-point path.' }
    Remove-Item -LiteralPath $path -Recurse -Force
}

function Invoke-FrameGenNGTechnicalBackupRetention {
    param([Parameter(Mandatory)][string]$UserRoot, [string]$ActiveBackupRoot)

    $dataRoot = Get-FrameGenNGDataRoot -UserRoot $UserRoot
    $backupRoot = Join-Path $dataRoot 'backups'
    if (Test-Path -LiteralPath $backupRoot -PathType Container) {
        $active = if ([string]::IsNullOrWhiteSpace($ActiveBackupRoot)) { $null } else { [System.IO.Path]::GetFullPath($ActiveBackupRoot).TrimEnd('\') }
        $inactive = @(Get-ChildItem -LiteralPath $backupRoot -Directory -Force | Where-Object {
            $null -eq $active -or [System.IO.Path]::GetFullPath($_.FullName).TrimEnd('\') -ne $active
        } | Sort-Object LastWriteTime -Descending)
        foreach ($directory in @($inactive | Select-Object -Skip $script:TechnicalBackupLimit)) {
            Remove-Item -LiteralPath $directory.FullName -Recurse -Force
        }
    }
    foreach ($pattern in @('uninstalled-state-*.json', 'recovery-before-uninstall-*')) {
        $items = @(Get-ChildItem -LiteralPath $dataRoot -Filter $pattern -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        foreach ($item in @($items | Select-Object -Skip $script:RecoveryArtifactLimit)) { Remove-Item -LiteralPath $item.FullName -Recurse -Force }
    }
}
