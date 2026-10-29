[CmdletBinding()]
param([Parameter(Mandatory)][string]$RequestPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:FileMoveAttemptLimit = 20
$script:RetryDelayMilliseconds = 250
$script:ManagerExitAttemptLimit = 120

function Write-UpdateLog {
    param([Parameter(Mandatory)][string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
    [System.IO.File]::AppendAllText($script:LogPath, "$line`r`n", [System.Text.UTF8Encoding]::new($false))
}

function Test-PathInsideRoot {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Root)
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $allowed = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $full.StartsWith($allowed + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Move-WithRetry {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination)
    $lastError = $null
    for ($attempt = 1; $attempt -le $script:FileMoveAttemptLimit; $attempt++) {
        try {
            Move-Item -LiteralPath $Source -Destination $Destination -Force
            return
        } catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds $script:RetryDelayMilliseconds
        }
    }
    throw "Unable to move $Source to $Destination after multiple attempts: $lastError"
}

function Clear-DirectoryContents {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
    foreach ($item in Get-ChildItem -LiteralPath $Path -Force) {
        Remove-Item -LiteralPath $item.FullName -Recurse -Force
    }
}

function Copy-DirectoryContents {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination)
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

function Set-PreservedFrameGenerationSettings {
    param([Parameter(Mandatory)]$Snapshot)
    if (-not [bool]$Snapshot.available) { return }
    $settingsPath = [string]$Snapshot.path
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { throw "Settings file is missing after update: $settingsPath" }
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    if ([bool]$Snapshot.enabledExists) {
        $settings | Add-Member -NotePropertyName 'BeamNGFrameGenerationEnabled' -NotePropertyValue ([bool]$Snapshot.enabled) -Force
    }
    if ([bool]$Snapshot.multiplierExists) {
        $settings | Add-Member -NotePropertyName 'BeamNGFrameGenerationMultiplier' -NotePropertyValue ([int]$Snapshot.multiplier) -Force
    }
    $json = $settings | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($settingsPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Write-TransactionResult {
    param([Parameter(Mandatory)]$TransactionResult, [Parameter(Mandatory)][string]$Path)
    $json = $TransactionResult | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Wait-ForManagerExit {
    param([Parameter(Mandatory)][int]$ProcessId)
    if ($ProcessId -le 0 -or $ProcessId -eq $PID) { return }

    for ($attempt = 0; $attempt -lt $script:ManagerExitAttemptLimit; $attempt++) {
        if ($null -eq (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) { return }
        Start-Sleep -Milliseconds $script:RetryDelayMilliseconds
    }
    throw 'The previous manager process did not close in time.'
}

function Show-TransactionResult {
    param([string]$Text, [string]$Title, [string]$Icon)
    if ([bool]$script:Request.silent) { return }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($Text, $Title, 'OK', $Icon) | Out-Null
}

$requestFullPath = [System.IO.Path]::GetFullPath($RequestPath)
if (-not (Test-Path -LiteralPath $requestFullPath -PathType Leaf)) { throw "Update request not found: $requestFullPath" }
$script:Request = Get-Content -LiteralPath $requestFullPath -Raw | ConvertFrom-Json
$workRoot = Split-Path -Parent $requestFullPath
$script:LogPath = Join-Path $workRoot 'update.log'
$resultPath = Join-Path $workRoot 'update-result.json'
$packageRoot = [System.IO.Path]::GetFullPath([string]$script:Request.packageRoot).TrimEnd('\')
$stagedPackageRoot = [System.IO.Path]::GetFullPath([string]$script:Request.stagedPackageRoot).TrimEnd('\')
$gameRoot = [System.IO.Path]::GetFullPath([string]$script:Request.gameRoot).TrimEnd('\')
$userRoot = [System.IO.Path]::GetFullPath([string]$script:Request.userRoot).TrimEnd('\')
$packageBackupRoot = $null
$backupParent = $null
$wasInstalled = $false
$oldUninstalled = $false
$packageSwapped = $false
$profile = $null
$oldVersion = $null
$settingsSnapshot = [pscustomobject]@{ available = $false }
$operation = if ($script:Request.PSObject.Properties.Name -contains 'operation') { [string]$script:Request.operation } else { 'update' }
$desiredInstalled = $null
$desiredProfile = $null
$desiredSettings = $null

try {
    Write-UpdateLog -Message "Starting $operation transaction to v$($script:Request.expectedVersion)."
    if (-not (Test-PathInsideRoot -Path $packageRoot -Root $gameRoot)) { throw 'The package folder is outside the BeamNG root.' }
    if (-not (Test-PathInsideRoot -Path $stagedPackageRoot -Root $userRoot)) { throw 'The staged package is outside the BeamNG user folder.' }
    if ((Split-Path -Leaf $packageRoot) -ne 'FrameGenNG') { throw 'The active package folder must be named FrameGenNG.' }
    if ((Split-Path -Leaf $stagedPackageRoot) -ne 'FrameGenNG') { throw 'The staged package folder must be named FrameGenNG.' }
    foreach ($required in @(
        (Join-Path $packageRoot 'manager\FrameGenNG.Core.psm1'),
        (Join-Path $stagedPackageRoot 'manager\FrameGenNG.Core.psm1'),
        (Join-Path $stagedPackageRoot 'VERSION')
    )) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required update file not found: $required" }
    }
    $stagedVersion = (Get-Content -LiteralPath (Join-Path $stagedPackageRoot 'VERSION') -Raw).Trim()
    if ($stagedVersion -ne [string]$script:Request.expectedVersion) { throw "Staged version $stagedVersion does not match the requested version." }
    $stagedUpdateModule = Import-Module (Join-Path $stagedPackageRoot 'manager\FrameGenNG.Update.psm1') -Force -PassThru
    & "$($stagedUpdateModule.Name)\Assert-FrameGenNGStagedPackage" -PackageRoot $stagedPackageRoot -ExpectedVersion $stagedVersion
    Remove-Module $stagedUpdateModule.Name -Force -ErrorAction SilentlyContinue

    Wait-ForManagerExit -ProcessId ([int]$script:Request.managerProcessId)

    $oldCorePath = Join-Path $packageRoot 'manager\FrameGenNG.Core.psm1'
    Import-Module $oldCorePath -Force
    $oldVersion = Get-FrameGenNGVersion
    $status = Get-FrameGenNGStatus -GameRoot $gameRoot -LauncherIni ([string]$script:Request.launcherIni)
    $wasInstalled = [bool]$status.installed
    if ($wasInstalled) {
        $state = Get-Content -LiteralPath ([string]$status.statePath) -Raw | ConvertFrom-Json
        $profile = [string]$state.profile
        $settingsPath = [string]$state.settingsPath
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $settingsSnapshot = [pscustomobject]@{
            available = $true
            path = $settingsPath
            enabledExists = $settings.PSObject.Properties.Name -contains 'BeamNGFrameGenerationEnabled'
            enabled = if ($settings.PSObject.Properties.Name -contains 'BeamNGFrameGenerationEnabled') { [bool]$settings.BeamNGFrameGenerationEnabled } else { $false }
            multiplierExists = $settings.PSObject.Properties.Name -contains 'BeamNGFrameGenerationMultiplier'
            multiplier = if ($settings.PSObject.Properties.Name -contains 'BeamNGFrameGenerationMultiplier') { [int]$settings.BeamNGFrameGenerationMultiplier } else { 2 }
        }
    }

    $desiredInstalled = if ($script:Request.PSObject.Properties.Name -contains 'targetInstalled') { [bool]$script:Request.targetInstalled } else { $wasInstalled }
    $desiredProfile = if ($script:Request.PSObject.Properties.Name -contains 'targetProfile' -and -not [string]::IsNullOrWhiteSpace([string]$script:Request.targetProfile)) { [string]$script:Request.targetProfile } else { $profile }
    $desiredSettings = if ($script:Request.PSObject.Properties.Name -contains 'targetSettings' -and $null -ne $script:Request.targetSettings) { $script:Request.targetSettings } else { $settingsSnapshot }

    $restoreReason = if ($operation -eq 'restore') { 'before-restore' } else { 'before-update' }
    New-FrameGenNGRestorePoint -UserRoot $userRoot -Reason $restoreReason -GameRoot $gameRoot -LauncherIni ([string]$script:Request.launcherIni) | Out-Null
    Write-UpdateLog -Message "Created a durable $restoreReason restore point."

    $backupParent = Join-Path $userRoot ('FrameGenNG\package-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + "-v$oldVersion-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
    Copy-Item -LiteralPath $packageRoot -Destination $backupParent -Recurse -Force
    $packageBackupRoot = Join-Path $backupParent 'FrameGenNG'
    Write-UpdateLog -Message "Package backup created at $packageBackupRoot."

    if ($wasInstalled) {
        Uninstall-FrameGenNG -GameRoot $gameRoot -LauncherIni ([string]$script:Request.launcherIni) -SkipRestorePoint | Out-Null
        $oldUninstalled = $true
        Write-UpdateLog -Message "Uninstalled v$oldVersion and restored the original game files."
    }
    Remove-Module FrameGenNG.Core -Force -ErrorAction SilentlyContinue

    $packageSwapped = $true
    Clear-DirectoryContents -Path $packageRoot
    Copy-DirectoryContents -Source $stagedPackageRoot -Destination $packageRoot
    Write-UpdateLog -Message 'Replaced the package folder.'

    $newCorePath = Join-Path $packageRoot 'manager\FrameGenNG.Core.psm1'
    Import-Module $newCorePath -Force
    if ($desiredInstalled) {
        Install-FrameGenNG -GameRoot $gameRoot -LauncherIni ([string]$script:Request.launcherIni) -Profile $desiredProfile -SkipRestorePoint | Out-Null
        Set-PreservedFrameGenerationSettings -Snapshot $desiredSettings
        Write-UpdateLog -Message "Installed v$stagedVersion with profile $desiredProfile and restored the selected Frame Generation settings."
    }

    if (Test-Path -LiteralPath $backupParent) {
        Remove-Item -LiteralPath $backupParent -Recurse -Force
        $packageBackupRoot = $null
        Write-UpdateLog -Message 'Removed the temporary package rollback copy after the successful transaction.'
    }
    $transactionResult = [pscustomobject][ordered]@{ success = $true; operation = $operation; fromVersion = $oldVersion; toVersion = $stagedVersion; packageBackup = $packageBackupRoot; log = $script:LogPath }
    Write-TransactionResult -TransactionResult $transactionResult -Path $resultPath
    Write-UpdateLog -Message 'Update completed successfully.'
    $successTitle = if ($operation -eq 'restore') { 'Restore complete' } else { 'FrameGenNG update complete' }
    $successText = if ($operation -eq 'restore') { "FrameGenNG was restored to v$stagedVersion.`r`n`r`nA safety restore point of the previous state was kept." } else { "FrameGenNG was updated to v$stagedVersion.`r`n`r`nYour Frame Generation settings were preserved." }
    Show-TransactionResult -Text $successText -Title $successTitle -Icon 'Information'
    if ([bool]$script:Request.restartManager -and -not [bool]$script:Request.silent) {
        $managerLauncher = Join-Path $packageRoot 'FrameGenNG Manager.vbs'
        Start-Process -FilePath 'wscript.exe' -ArgumentList ('"{0}"' -f $managerLauncher.Replace('"', '""'))
    }
    exit 0
} catch {
    $updateError = $_.Exception.Message
    Write-UpdateLog -Message "Update failed: $updateError"
    $rollbackError = $null
    try {
        Remove-Module FrameGenNG.Core -Force -ErrorAction SilentlyContinue
        if ($packageSwapped -and (Test-Path -LiteralPath $packageRoot)) {
            $newCore = Join-Path $packageRoot 'manager\FrameGenNG.Core.psm1'
            if (Test-Path -LiteralPath $newCore -PathType Leaf) {
                Import-Module $newCore -Force
                $newStatus = Get-FrameGenNGStatus -GameRoot $gameRoot -LauncherIni ([string]$script:Request.launcherIni)
                if ([bool]$newStatus.installed) { Uninstall-FrameGenNG -GameRoot $gameRoot -LauncherIni ([string]$script:Request.launcherIni) -SkipRestorePoint | Out-Null }
                Remove-Module FrameGenNG.Core -Force -ErrorAction SilentlyContinue
            }
            Clear-DirectoryContents -Path $packageRoot
        }
        if ($null -ne $packageBackupRoot -and (Test-Path -LiteralPath $packageBackupRoot)) {
            Copy-DirectoryContents -Source $packageBackupRoot -Destination $packageRoot
        }
        if ($wasInstalled) {
            $oldCore = Join-Path $packageRoot 'manager\FrameGenNG.Core.psm1'
            Import-Module $oldCore -Force
            $oldStatus = Get-FrameGenNGStatus -GameRoot $gameRoot -LauncherIni ([string]$script:Request.launcherIni)
            if (-not [bool]$oldStatus.installed) { Install-FrameGenNG -GameRoot $gameRoot -LauncherIni ([string]$script:Request.launcherIni) -Profile $profile -SkipRestorePoint | Out-Null }
            Set-PreservedFrameGenerationSettings -Snapshot $settingsSnapshot
        }
        if (Test-Path -LiteralPath $backupParent) {
            Remove-Item -LiteralPath $backupParent -Recurse -Force
            $packageBackupRoot = $null
        }
        Write-UpdateLog -Message 'Rollback completed successfully.'
    } catch {
        $rollbackError = $_.Exception.Message
        Write-UpdateLog -Message "Rollback failed: $rollbackError"
    }
    $transactionResult = [pscustomobject][ordered]@{ success = $false; error = $updateError; rollbackError = $rollbackError; packageBackup = $packageBackupRoot; log = $script:LogPath }
    Write-TransactionResult -TransactionResult $transactionResult -Path $resultPath
    $message = "The $operation could not be completed.`r`n`r`n$updateError"
    if ($null -eq $rollbackError) { $message += "`r`n`r`nThe previous version was restored." } else { $message += "`r`n`r`nAutomatic rollback also failed: $rollbackError`r`nPackage backup: $packageBackupRoot" }
    Show-TransactionResult -Text $message -Title 'FrameGenNG update failed' -Icon 'Error'
    exit 1
}
