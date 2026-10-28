Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:DefaultReleaseApi = 'https://api.github.com/repos/ragnarok179/FrameGenNG/releases?per_page=20'

function ConvertTo-FrameGenNGSemVer {
    param([Parameter(Mandatory)][string]$Version)

    $value = $Version.Trim()
    if ($value.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase)) {
        $value = $value.Substring(1)
    }
    if ($value -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z.-]+)?$') {
        throw "Invalid semantic version: $Version"
    }
    return [pscustomobject]@{
        Original = $Version
        Normalized = $value
        Major = [int]$Matches[1]
        Minor = [int]$Matches[2]
        Patch = [int]$Matches[3]
        Prerelease = if ([string]::IsNullOrWhiteSpace($Matches[4])) { $null } else { [string]$Matches[4] }
    }
}

function Compare-FrameGenNGVersion {
    param(
        [Parameter(Mandatory)][string]$Left,
        [Parameter(Mandatory)][string]$Right
    )

    $a = ConvertTo-FrameGenNGSemVer -Version $Left
    $b = ConvertTo-FrameGenNGSemVer -Version $Right
    foreach ($field in @('Major', 'Minor', 'Patch')) {
        if ($a.$field -lt $b.$field) { return -1 }
        if ($a.$field -gt $b.$field) { return 1 }
    }
    if ($null -eq $a.Prerelease -and $null -eq $b.Prerelease) { return 0 }
    if ($null -eq $a.Prerelease) { return 1 }
    if ($null -eq $b.Prerelease) { return -1 }

    $leftParts = @($a.Prerelease -split '\.')
    $rightParts = @($b.Prerelease -split '\.')
    $count = [Math]::Max($leftParts.Count, $rightParts.Count)
    for ($i = 0; $i -lt $count; $i++) {
        if ($i -ge $leftParts.Count) { return -1 }
        if ($i -ge $rightParts.Count) { return 1 }
        $leftNumber = 0L
        $rightNumber = 0L
        $leftNumeric = [long]::TryParse($leftParts[$i], [ref]$leftNumber)
        $rightNumeric = [long]::TryParse($rightParts[$i], [ref]$rightNumber)
        if ($leftNumeric -and $rightNumeric) {
            if ($leftNumber -lt $rightNumber) { return -1 }
            if ($leftNumber -gt $rightNumber) { return 1 }
            continue
        }
        if ($leftNumeric -and -not $rightNumeric) { return -1 }
        if (-not $leftNumeric -and $rightNumeric) { return 1 }
        $comparison = [string]::Compare($leftParts[$i], $rightParts[$i], [System.StringComparison]::OrdinalIgnoreCase)
        if ($comparison -lt 0) { return -1 }
        if ($comparison -gt 0) { return 1 }
    }
    return 0
}

function Select-FrameGenNGRelease {
    param(
        [Parameter(Mandatory)][string]$CurrentVersion,
        [Parameter(Mandatory)]$Releases,
        [bool]$IncludePrerelease = $false
    )

    $selected = $null
    $selectedVersion = $null
    foreach ($release in @($Releases)) {
        if ([bool]$release.draft) { continue }
        if ([bool]$release.prerelease -and -not $IncludePrerelease) { continue }
        try { $candidate = (ConvertTo-FrameGenNGSemVer -Version ([string]$release.tag_name)).Normalized } catch { continue }
        if ($null -eq $selected -or (Compare-FrameGenNGVersion -Left $candidate -Right $selectedVersion) -gt 0) {
            $selected = $release
            $selectedVersion = $candidate
        }
    }
    if ($null -eq $selected) {
        return [pscustomobject]@{
            CurrentVersion = $CurrentVersion
            LatestVersion = $null
            UpdateAvailable = $false
            ReleaseUrl = 'https://github.com/ragnarok179/FrameGenNG/releases'
            Message = 'No compatible published release was found.'
        }
    }

    $zipName = "FrameGenNG-v$selectedVersion.zip"
    $checksumName = "$zipName.sha256"
    $zipAsset = @($selected.assets | Where-Object { [string]$_.name -ieq $zipName } | Select-Object -First 1)
    $checksumAsset = @($selected.assets | Where-Object { [string]$_.name -ieq $checksumName } | Select-Object -First 1)
    $available = (Compare-FrameGenNGVersion -Left $selectedVersion -Right $CurrentVersion) -gt 0
    if ($available -and ($zipAsset.Count -ne 1 -or $checksumAsset.Count -ne 1)) {
        throw "Release v$selectedVersion is missing $zipName or $checksumName."
    }
    return [pscustomobject]@{
        CurrentVersion = $CurrentVersion
        LatestVersion = $selectedVersion
        UpdateAvailable = $available
        IsPrerelease = [bool]$selected.prerelease
        ReleaseUrl = [string]$selected.html_url
        ReleaseName = [string]$selected.name
        ReleaseNotes = [string]$selected.body
        ZipName = if ($zipAsset.Count -eq 1) { [string]$zipAsset[0].name } else { $null }
        ZipUrl = if ($zipAsset.Count -eq 1) { [string]$zipAsset[0].browser_download_url } else { $null }
        ZipDigest = if ($zipAsset.Count -eq 1 -and $zipAsset[0].PSObject.Properties.Name -contains 'digest') { [string]$zipAsset[0].digest } else { $null }
        ChecksumName = if ($checksumAsset.Count -eq 1) { [string]$checksumAsset[0].name } else { $null }
        ChecksumUrl = if ($checksumAsset.Count -eq 1) { [string]$checksumAsset[0].browser_download_url } else { $null }
        Message = if ($available) { "FrameGenNG v$selectedVersion is available." } else { 'FrameGenNG is up to date.' }
    }
}

function Get-FrameGenNGUpdateInfo {
    param(
        [Parameter(Mandatory)][string]$CurrentVersion,
        [bool]$IncludePrerelease = $false,
        [string]$ReleaseApiUri = $script:DefaultReleaseApi,
        [int]$TimeoutSec = 10
    )

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{
            Accept = 'application/vnd.github+json'
            'User-Agent' = "FrameGenNG/$CurrentVersion"
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        $releases = Invoke-RestMethod -Method Get -Uri $ReleaseApiUri -Headers $headers -TimeoutSec $TimeoutSec
        return Select-FrameGenNGRelease -CurrentVersion $CurrentVersion -Releases $releases -IncludePrerelease $IncludePrerelease
    } catch {
        throw "Unable to check GitHub Releases: $($_.Exception.Message)"
    }
}

function Assert-FrameGenNGUpdateArchive {
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$ChecksumPath,
        [Parameter(Mandatory)][string]$ExpectedVersion,
        [string]$ApiDigest
    )

    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) { throw "Downloaded ZIP not found: $ZipPath" }
    if (-not (Test-Path -LiteralPath $ChecksumPath -PathType Leaf)) { throw "Checksum file not found: $ChecksumPath" }
    $checksumText = Get-Content -LiteralPath $ChecksumPath -Raw
    if ($checksumText -notmatch '(?i)\b([0-9a-f]{64})\b') { throw 'The release checksum file is invalid.' }
    $expectedHash = $Matches[1].ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) { throw "SHA-256 mismatch. Expected $expectedHash, received $actualHash." }
    if (-not [string]::IsNullOrWhiteSpace($ApiDigest)) {
        if ($ApiDigest -notmatch '(?i)^sha256:([0-9a-f]{64})$') { throw "Unsupported GitHub asset digest: $ApiDigest" }
        if ($actualHash -ne $Matches[1].ToLowerInvariant()) { throw 'The ZIP does not match the digest published by GitHub.' }
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $normalizedEntryNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ($name.StartsWith('/') -or $name -match '^[A-Za-z]:' -or $name -notmatch '^FrameGenNG/' -or $name -match '(^|/)\.\.(/|$)') {
                throw "Unsafe ZIP entry: $name"
            }
            [void]$normalizedEntryNames.Add($name)
        }
        $required = @(
            'FrameGenNG/VERSION',
            'FrameGenNG/FrameGenNG Manager.vbs',
            'FrameGenNG/manager/FrameGenNG.Core.psm1',
            'FrameGenNG/manager/Core/FrameGenNG.Recovery.ps1',
            'FrameGenNG/manager/FrameGenNG.Update.psm1',
            'FrameGenNG/manager/FrameGenNG.Diagnostics.psm1',
            'FrameGenNG/manager/FrameGenNG.Ui.psm1',
            'FrameGenNG/manager/FrameGenNG-Updater.ps1',
            'FrameGenNG/payload/manifest.json'
        )
        foreach ($requiredEntry in $required) {
            if (-not $normalizedEntryNames.Contains($requiredEntry)) { throw "Required ZIP entry is missing: $requiredEntry" }
        }
    } finally {
        $zip.Dispose()
    }
    return [pscustomobject]@{ Version = $ExpectedVersion; Sha256 = $actualHash }
}

function Assert-FrameGenNGStagedPackage {
    param(
        [Parameter(Mandatory)][string]$PackageRoot,
        [Parameter(Mandatory)][string]$ExpectedVersion
    )
    $version = (Get-Content -LiteralPath (Join-Path $PackageRoot 'VERSION') -Raw).Trim()
    if ((Compare-FrameGenNGVersion -Left $version -Right $ExpectedVersion) -ne 0) {
        throw "Downloaded package version $version does not match release $ExpectedVersion."
    }
    $manifestPath = Join-Path $PackageRoot 'payload\manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([string]$manifest.packageVersion -ne $version) { throw 'The payload manifest version does not match the staged package.' }
    $payloadRoot = [System.IO.Path]::GetFullPath((Join-Path $PackageRoot 'payload')).TrimEnd('\')
    foreach ($entry in @($manifest.files)) {
        $relative = ([string]$entry.path).Replace('/', '\')
        $path = [System.IO.Path]::GetFullPath((Join-Path $payloadRoot $relative))
        if (-not $path.StartsWith($payloadRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe payload path: $relative" }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Staged payload file is missing: $relative" }
        if ((Get-Item -LiteralPath $path).Length -ne [long]$entry.size) { throw "Staged payload size mismatch: $relative" }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "Staged payload checksum mismatch: $relative" }
    }
}

function Save-FrameGenNGUpdatePackage {
    param(
        [Parameter(Mandatory)]$UpdateInfo,
        [Parameter(Mandatory)][string]$DestinationRoot
    )

    if (-not [bool]$UpdateInfo.UpdateAvailable) { throw 'No newer FrameGenNG version is available.' }
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
    $zipPath = Join-Path $DestinationRoot ([string]$UpdateInfo.ZipName)
    $checksumPath = Join-Path $DestinationRoot ([string]$UpdateInfo.ChecksumName)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ 'User-Agent' = "FrameGenNG/$($UpdateInfo.CurrentVersion)" }
    Invoke-WebRequest -UseBasicParsing -Uri ([string]$UpdateInfo.ZipUrl) -Headers $headers -TimeoutSec 60 -OutFile $zipPath
    Invoke-WebRequest -UseBasicParsing -Uri ([string]$UpdateInfo.ChecksumUrl) -Headers $headers -TimeoutSec 60 -OutFile $checksumPath
    Assert-FrameGenNGUpdateArchive -ZipPath $zipPath -ChecksumPath $checksumPath -ExpectedVersion ([string]$UpdateInfo.LatestVersion) -ApiDigest ([string]$UpdateInfo.ZipDigest) | Out-Null

    $extractRoot = Join-Path $DestinationRoot 'extracted'
    if (Test-Path -LiteralPath $extractRoot) { Remove-Item -LiteralPath $extractRoot -Recurse -Force }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
    $packageRoot = Join-Path $extractRoot 'FrameGenNG'
    Assert-FrameGenNGStagedPackage -PackageRoot $packageRoot -ExpectedVersion ([string]$UpdateInfo.LatestVersion)
    return [pscustomobject]@{ PackageRoot = $packageRoot; ZipPath = $zipPath; Sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant() }
}

function Start-FrameGenNGUpdateHelper {
    param(
        [Parameter(Mandatory)][string]$PackageRoot,
        [Parameter(Mandatory)][string]$WorkRoot,
        [Parameter(Mandatory)]$Request
    )

    $helperPath = Join-Path $WorkRoot 'FrameGenNG-Updater.ps1'
    Copy-Item -LiteralPath (Join-Path $PackageRoot 'manager\FrameGenNG-Updater.ps1') -Destination $helperPath -Force

    $requestPath = Join-Path $WorkRoot 'update-request.json'
    $requestJson = $Request | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($requestPath, $requestJson, [System.Text.UTF8Encoding]::new($false))

    $powerShellPath = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powerShellPath)) { $powerShellPath = 'powershell.exe' }
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -RequestPath "{1}"' -f $helperPath.Replace('"', '""'), $requestPath.Replace('"', '""')
    $process = Start-Process -FilePath $powerShellPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    return [pscustomobject]@{ ProcessId = $process.Id; WorkRoot = $WorkRoot; RequestPath = $requestPath }
}

function Start-FrameGenNGUpdate {
    param(
        [Parameter(Mandatory)]$UpdateInfo,
        [Parameter(Mandatory)][string]$PackageRoot,
        [Parameter(Mandatory)][string]$GameRoot,
        [Parameter(Mandatory)][string]$UserRoot,
        [string]$LauncherIni,
        [int]$ManagerProcessId = $PID
    )

    $updatesRoot = Join-Path $UserRoot 'FrameGenNG\updates'
    $workRoot = Join-Path $updatesRoot ("pending-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    try {
        $download = Save-FrameGenNGUpdatePackage -UpdateInfo $UpdateInfo -DestinationRoot $workRoot
        $request = [pscustomobject][ordered]@{
            schemaVersion = 1
            packageRoot = [System.IO.Path]::GetFullPath($PackageRoot)
            stagedPackageRoot = [System.IO.Path]::GetFullPath([string]$download.PackageRoot)
            gameRoot = [System.IO.Path]::GetFullPath($GameRoot)
            userRoot = [System.IO.Path]::GetFullPath($UserRoot)
            launcherIni = $LauncherIni
            expectedVersion = [string]$UpdateInfo.LatestVersion
            managerProcessId = $ManagerProcessId
            restartManager = $true
            silent = $false
        }
        return Start-FrameGenNGUpdateHelper -PackageRoot $PackageRoot -WorkRoot $workRoot -Request $request
    } catch {
        if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
        throw
    }
}

function Start-FrameGenNGRestore {
    param(
        [Parameter(Mandatory)]$RestorePoint,
        [Parameter(Mandatory)][string]$PackageRoot,
        [Parameter(Mandatory)][string]$GameRoot,
        [Parameter(Mandatory)][string]$UserRoot,
        [string]$LauncherIni,
        [int]$ManagerProcessId = $PID
    )

    $restoreRoot = [System.IO.Path]::GetFullPath((Join-Path $UserRoot 'FrameGenNG\restore-points')).TrimEnd('\')
    $pointPath = [System.IO.Path]::GetFullPath([string]$RestorePoint.path).TrimEnd('\')
    if (-not $pointPath.StartsWith($restoreRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe restore-point path.' }
    $zipPath = [System.IO.Path]::GetFullPath([string]$RestorePoint.packagePath)
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw 'The restore-point package is missing.' }
    $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne ([string]$RestorePoint.packageSha256).ToLowerInvariant()) { throw 'The restore-point package failed its integrity check.' }

    if ($null -ne $RestorePoint.gameIdentity -and -not [string]::IsNullOrWhiteSpace([string]$RestorePoint.gameIdentity.executableSha256)) {
        $currentExecutable = Join-Path $GameRoot 'Bin64\BeamNG.drive.x64.exe'
        $currentHash = (Get-FileHash -LiteralPath $currentExecutable -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($currentHash -ne ([string]$RestorePoint.gameIdentity.executableSha256).ToLowerInvariant()) {
            throw "This restore point was created for BeamNG $($RestorePoint.gameIdentity.version). The current game executable is different. Use Repair with the current FrameGenNG version instead."
        }
    }

    $workRoot = Join-Path $UserRoot ('FrameGenNG\updates\restore-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    try {
        $extractRoot = Join-Path $workRoot 'extracted'
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
        $stagedPackageRoot = Join-Path $extractRoot 'FrameGenNG'
        Assert-FrameGenNGStagedPackage -PackageRoot $stagedPackageRoot -ExpectedVersion ([string]$RestorePoint.version)
        $request = [pscustomobject][ordered]@{
            schemaVersion = 2
            operation = 'restore'
            restorePointId = [string]$RestorePoint.id
            packageRoot = [System.IO.Path]::GetFullPath($PackageRoot)
            stagedPackageRoot = [System.IO.Path]::GetFullPath($stagedPackageRoot)
            gameRoot = [System.IO.Path]::GetFullPath($GameRoot)
            userRoot = [System.IO.Path]::GetFullPath($UserRoot)
            launcherIni = $LauncherIni
            expectedVersion = [string]$RestorePoint.version
            targetInstalled = [bool]$RestorePoint.installed
            targetProfile = [string]$RestorePoint.profile
            targetSettings = $RestorePoint.settings
            managerProcessId = $ManagerProcessId
            restartManager = $true
            silent = $false
        }
        return Start-FrameGenNGUpdateHelper -PackageRoot $PackageRoot -WorkRoot $workRoot -Request $request
    } catch {
        if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
        throw
    }
}

Export-ModuleMember -Function @(
    'ConvertTo-FrameGenNGSemVer',
    'Compare-FrameGenNGVersion',
    'Select-FrameGenNGRelease',
    'Get-FrameGenNGUpdateInfo',
    'Assert-FrameGenNGUpdateArchive',
    'Assert-FrameGenNGStagedPackage',
    'Save-FrameGenNGUpdatePackage',
    'Start-FrameGenNGUpdate',
    'Start-FrameGenNGRestore'
)
