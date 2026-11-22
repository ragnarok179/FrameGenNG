Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:SettingsFileName = 'manager-settings.json'
$script:DiagnosticLogLimit = 7
$script:DiagnosticLogSizeLimit = 2MB
$script:DiagnosticExportLimit = 5
$script:DiagnosticNativeLogLimit = 5
$script:DiagnosticTransactionLogLimit = 5
$script:DiagnosticCrashDumpLimit = 5
$script:DiagnosticTextTailLines = 12000

function Get-FrameGenNGDiagnosticRoot {
    param([Parameter(Mandatory)][string]$UserRoot)
    return Join-Path $UserRoot 'FrameGenNG\diagnostics'
}

function Get-FrameGenNGManagerSettings {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$UserRoot)
    $path = Join-Path (Join-Path $UserRoot 'FrameGenNG') $script:SettingsFileName
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try {
            $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            return [pscustomobject][ordered]@{
                schemaVersion = 1
                advancedDiagnostics = [bool]$value.advancedDiagnostics
            }
        } catch {
            # A damaged preference file falls back to the safe, disabled state.
        }
    }
    return [pscustomobject][ordered]@{ schemaVersion = 1; advancedDiagnostics = $false }
}

function Set-FrameGenNGAdvancedDiagnostics {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$UserRoot, [Parameter(Mandatory)][bool]$Enabled)
    $path = Join-Path (Join-Path $UserRoot 'FrameGenNG') $script:SettingsFileName
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    $value = [pscustomobject][ordered]@{ schemaVersion = 1; advancedDiagnostics = $Enabled }
    [System.IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
    return $value
}

function Set-FrameGenNGNativeDiagnosticLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$GameRoot,
        [Parameter(Mandatory)][bool]$Enabled
    )

    $configPath = Join-Path $GameRoot 'Bin64\FrameGenNG.ini'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return $false }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]](Get-Content -LiteralPath $configPath))
    $logSectionIndex = -1
    $nextSectionIndex = $lines.Count
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -ieq '[Log]') {
            $logSectionIndex = $index
            continue
        }
        if ($logSectionIndex -ge 0 -and $index -gt $logSectionIndex -and $lines[$index].Trim() -match '^\[.+\]$') {
            $nextSectionIndex = $index
            break
        }
    }
    if ($logSectionIndex -lt 0) { throw "The [Log] section is missing from $configPath" }

    $value = if ($Enabled) { 'true' } else { 'false' }
    $settingIndex = -1
    for ($index = $logSectionIndex + 1; $index -lt $nextSectionIndex; $index++) {
        if ($lines[$index] -match '^\s*LogToFile\s*=') {
            $settingIndex = $index
            break
        }
    }
    if ($settingIndex -ge 0) {
        $lines[$settingIndex] = "LogToFile=$value"
    } else {
        $lines.Insert($nextSectionIndex, "LogToFile=$value")
    }
    [System.IO.File]::WriteAllLines($configPath, $lines, [System.Text.UTF8Encoding]::new($false))
    return $true
}

function Write-FrameGenNGDiagnosticLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$UserRoot,
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Warning','Error')][string]$Level = 'Info',
        [switch]$Force
    )
    $settings = Get-FrameGenNGManagerSettings -UserRoot $UserRoot
    if (-not $Force -and -not [bool]$settings.advancedDiagnostics) { return $null }

    $logsRoot = Join-Path (Get-FrameGenNGDiagnosticRoot -UserRoot $UserRoot) 'manager-logs'
    New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null
    $path = Join-Path $logsRoot ("manager-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))
    if ((Test-Path -LiteralPath $path -PathType Leaf) -and (Get-Item -LiteralPath $path).Length -ge $script:DiagnosticLogSizeLimit) {
        $path = Join-Path $logsRoot ("manager-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    $line = "{0} [{1}] {2}`r`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level.ToUpperInvariant(), $Message
    [System.IO.File]::AppendAllText($path, $line, [System.Text.UTF8Encoding]::new($false))
    foreach ($old in @(Get-ChildItem -LiteralPath $logsRoot -Filter 'manager-*.log' -File -Force | Sort-Object LastWriteTime -Descending | Select-Object -Skip $script:DiagnosticLogLimit)) {
        Remove-Item -LiteralPath $old.FullName -Force
    }
    return $path
}

function Get-FrameGenNGDiagnosticSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Status)
    $issues = [System.Collections.Generic.List[string]]::new()
    if (-not [bool]$Status.installed) {
        $health = 'Not installed'
    } elseif ([bool]$Status.healthy) {
        $health = 'Installed and healthy'
    } else {
        $health = 'Attention required'
        if ($Status.PSObject.Properties.Name -contains 'stateRecoveredFromBackup' -and [bool]$Status.stateRecoveredFromBackup) { $issues.Add('The primary installation state was recovered from its backup.') }
        if ($Status.PSObject.Properties.Name -contains 'checks') {
            foreach ($check in @($Status.checks | Where-Object { -not [bool]$_.matchesInstalled })) { $issues.Add("Missing or modified: $($check.destination)") }
        }
    }
    return [pscustomobject][ordered]@{
        health = $health
        version = [string]$Status.version
        profile = if ($Status.PSObject.Properties.Name -contains 'profile') { [string]$Status.profile } else { $null }
        issues = $issues.ToArray()
    }
}

function Copy-DiagnosticTextTail {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination, [int]$Lines = $script:DiagnosticTextTailLines)
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return $false }

    $tail = [System.Collections.Generic.Queue[string]]::new()
    $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
    $stream = [System.IO.FileStream]::new($Source, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $share)
    try {
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $true)
        try {
            while (-not $reader.EndOfStream) {
                if ($tail.Count -ge $Lines) { $null = $tail.Dequeue() }
                $tail.Enqueue($reader.ReadLine())
            }
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }

    [System.IO.File]::WriteAllLines($Destination, $tail.ToArray(), [System.Text.UTF8Encoding]::new($false))
    return $true
}

function Get-FrameGenNGNativeDiagnosticLogs {
    param([Parameter(Mandatory)][string]$GameRoot)

    $binRoot = Join-Path $GameRoot 'Bin64'
    $rendererLogRoot = Join-Path $binRoot 'FGNGEngine\logs'
    $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    if (Test-Path -LiteralPath $binRoot -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $binRoot -File -Force -ErrorAction SilentlyContinue | Where-Object {
            if ($_.Name -match '^(FrameGenNG|FGNG|RTXMFG).*\.(log|json|jsonl)$') { return $true }
            if ($_.Extension -ine '.log') { return $false }

            try {
                $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
                $stream = [System.IO.FileStream]::new($_.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $share)
                try {
                    $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $true)
                    try { return ($reader.ReadLine() -match 'FrameGenNG') } finally { $reader.Dispose() }
                } finally { $stream.Dispose() }
            } catch {
                return $false
            }
        })) {
            $files.Add($file)
        }
    }
    if (Test-Path -LiteralPath $rendererLogRoot -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $rendererLogRoot -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(log|json|jsonl)$' })) {
            $files.Add($file)
        }
    }

    return @($files | Sort-Object LastWriteTime -Descending | Select-Object -First $script:DiagnosticNativeLogLimit)
}

function Get-FrameGenNGCrashDumpMetadata {
    $crashDumpRoot = Join-Path $env:LOCALAPPDATA 'CrashDumps'
    if (-not (Test-Path -LiteralPath $crashDumpRoot -PathType Container)) { return @() }

    return @(Get-ChildItem -LiteralPath $crashDumpRoot -Filter 'BeamNG.drive*.dmp' -File -Force -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $script:DiagnosticCrashDumpLimit |
        ForEach-Object {
            $processId = $null
            if ($_.Name -match '\.(?<processId>\d+)\.dmp$') { $processId = [int]$Matches.processId }
            [pscustomobject][ordered]@{
                name = $_.Name
                processId = $processId
                sizeBytes = [long]$_.Length
                lastWriteTime = $_.LastWriteTime.ToString('o')
                path = $_.FullName
            }
        })
}

function Get-FrameGenNGBeamNGSettingsSnapshot {
    param([Parameter(Mandatory)][string]$UserRoot)

    $settingsPath = Join-Path $UserRoot 'settings\settings.json'
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { return $null }

    try {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    } catch {
        return [pscustomobject][ordered]@{ error = $_.Exception.Message }
    }

    $snapshot = [ordered]@{}
    foreach ($name in @(
        'GraphicAntialiasType',
        'GraphicUpscalingQuality',
        'GraphicHDREnabled',
        'GraphicHDROutputModeName',
        'GraphicDisplayModes',
        'GraphicDisplayResolutions',
        'GraphicDisplayRefreshRate',
        'GraphicFullscreen',
        'BeamNGFrameGenerationEnabled',
        'BeamNGFrameGenerationMultiplier'
    )) {
        if ($settings.PSObject.Properties.Name -contains $name) { $snapshot[$name] = $settings.$name }
    }
    return [pscustomobject]$snapshot
}

function Export-FrameGenNGDiagnosticBundle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackageRoot,
        [Parameter(Mandatory)][string]$GameRoot,
        [Parameter(Mandatory)][string]$UserRoot,
        [Parameter(Mandatory)]$Status
    )
    $diagnosticRoot = Get-FrameGenNGDiagnosticRoot -UserRoot $UserRoot
    $exportsRoot = Join-Path $diagnosticRoot 'exports'
    $stageRoot = Join-Path $diagnosticRoot ('working-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stageRoot,$exportsRoot -Force | Out-Null
    try {
        $gpu = @()
        try {
            $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
                [pscustomobject][ordered]@{ name = [string]$_.Name; driverVersion = [string]$_.DriverVersion; adapterRam = [long]$_.AdapterRAM }
            })
        } catch {
            $gpu = @([pscustomobject]@{ name = 'Unavailable'; driverVersion = $null; adapterRam = 0 })
        }
        $report = [pscustomobject][ordered]@{
            schemaVersion = 1
            createdAt = (Get-Date).ToString('o')
            frameGenNGVersion = (Get-Content -LiteralPath (Join-Path $PackageRoot 'VERSION') -Raw).Trim()
            operatingSystem = [Environment]::OSVersion.VersionString
            powershellVersion = $PSVersionTable.PSVersion.ToString()
            gpu = $gpu
            gameRoot = [System.IO.Path]::GetFullPath($GameRoot)
            userRoot = [System.IO.Path]::GetFullPath($UserRoot)
            summary = Get-FrameGenNGDiagnosticSummary -Status $Status
            status = $Status
            advancedDiagnostics = [bool](Get-FrameGenNGManagerSettings -UserRoot $UserRoot).advancedDiagnostics
        }
        [System.IO.File]::WriteAllText((Join-Path $stageRoot 'report.json'), ($report | ConvertTo-Json -Depth 30), [System.Text.UTF8Encoding]::new($false))

        $settingsPath = Join-Path (Join-Path $UserRoot 'FrameGenNG') $script:SettingsFileName
        if (Test-Path -LiteralPath $settingsPath -PathType Leaf) { Copy-Item -LiteralPath $settingsPath -Destination (Join-Path $stageRoot 'manager-settings.json') -Force }
        $manifestPath = Join-Path $PackageRoot 'payload\manifest.json'
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) { Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stageRoot 'payload-manifest.json') -Force }
        if ($Status.PSObject.Properties.Name -contains 'statePath' -and -not [string]::IsNullOrWhiteSpace([string]$Status.statePath) -and (Test-Path -LiteralPath ([string]$Status.statePath) -PathType Leaf)) {
            Copy-Item -LiteralPath ([string]$Status.statePath) -Destination (Join-Path $stageRoot 'install-state.json') -Force
        }

        $beamngLogsRoot = Join-Path $stageRoot 'beamng-logs'
        New-Item -ItemType Directory -Path $beamngLogsRoot -Force | Out-Null
        foreach ($name in @('beamng.log','beamng.1.log')) {
            Copy-DiagnosticTextTail -Source (Join-Path $UserRoot $name) -Destination (Join-Path $beamngLogsRoot $name) | Out-Null
        }
        foreach ($name in @('beamng-launcher.log','beamng-launcher.1.log')) {
            Copy-DiagnosticTextTail -Source (Join-Path $UserRoot $name) -Destination (Join-Path $beamngLogsRoot $name) | Out-Null
        }

        $shutdownRoot = Join-Path $stageRoot 'shutdown'
        New-Item -ItemType Directory -Path $shutdownRoot -Force | Out-Null
        foreach ($name in @('frame_generation_shutdown.log','frame_generation_shutdown.signal','frame_generation_runtime.state')) {
            Copy-DiagnosticTextTail -Source (Join-Path $UserRoot "temp\$name") -Destination (Join-Path $shutdownRoot $name) | Out-Null
        }

        $settingsSnapshot = Get-FrameGenNGBeamNGSettingsSnapshot -UserRoot $UserRoot
        if ($null -ne $settingsSnapshot) {
            [System.IO.File]::WriteAllText(
                (Join-Path $stageRoot 'beamng-settings.json'),
                ($settingsSnapshot | ConvertTo-Json -Depth 10),
                [System.Text.UTF8Encoding]::new($false))
        }

        $crashDumps = @(Get-FrameGenNGCrashDumpMetadata)
        if ($crashDumps.Count -gt 0) {
            [System.IO.File]::WriteAllText(
                (Join-Path $stageRoot 'crash-dumps.json'),
                ($crashDumps | ConvertTo-Json -Depth 10),
                [System.Text.UTF8Encoding]::new($false))
        }

        $nativeConfigRoot = Join-Path $stageRoot 'native-config'
        New-Item -ItemType Directory -Path $nativeConfigRoot -Force | Out-Null
        foreach ($name in @('FrameGenNG.ini','FGNGEngine.ini')) {
            $source = Join-Path (Join-Path $GameRoot 'Bin64') $name
            if (Test-Path -LiteralPath $source -PathType Leaf) { Copy-Item -LiteralPath $source -Destination (Join-Path $nativeConfigRoot $name) -Force }
        }
        $nativeLogsRoot = Join-Path $stageRoot 'native-logs'
        New-Item -ItemType Directory -Path $nativeLogsRoot -Force | Out-Null
        foreach ($file in @(Get-FrameGenNGNativeDiagnosticLogs -GameRoot $GameRoot)) {
            Copy-DiagnosticTextTail -Source $file.FullName -Destination (Join-Path $nativeLogsRoot $file.Name) | Out-Null
        }
        $managerLogsRoot = Join-Path $diagnosticRoot 'manager-logs'
        if (Test-Path -LiteralPath $managerLogsRoot -PathType Container) {
            $destination = Join-Path $stageRoot 'manager-logs'; New-Item -ItemType Directory -Path $destination -Force | Out-Null
            foreach ($file in @(Get-ChildItem -LiteralPath $managerLogsRoot -Filter '*.log' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 7)) { Copy-Item -LiteralPath $file.FullName -Destination $destination -Force }
        }
        $updatesRoot = Join-Path $UserRoot 'FrameGenNG\updates'
        if (Test-Path -LiteralPath $updatesRoot -PathType Container) {
            $destination = Join-Path $stageRoot 'transaction-logs'; New-Item -ItemType Directory -Path $destination -Force | Out-Null
            $index = 0
            foreach ($file in @(Get-ChildItem -LiteralPath $updatesRoot -Filter 'update.log' -Recurse -File -Force | Sort-Object LastWriteTime -Descending | Select-Object -First $script:DiagnosticTransactionLogLimit)) {
                Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $destination ("transaction-{0:d2}.log" -f $index)) -Force
                $index++
            }
        }

        $zipPath = Join-Path $exportsRoot ("FrameGenNG-Diagnostics-{0}-{1}.zip" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [Guid]::NewGuid().ToString('N').Substring(0, 6))
        Compress-Archive -Path (Join-Path $stageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
        foreach ($old in @(Get-ChildItem -LiteralPath $exportsRoot -Filter 'FrameGenNG-Diagnostics-*.zip' -File -Force | Sort-Object LastWriteTime -Descending | Select-Object -Skip $script:DiagnosticExportLimit)) {
            Remove-Item -LiteralPath $old.FullName -Force
        }
        return [pscustomobject][ordered]@{ path = $zipPath; sizeBytes = [long](Get-Item -LiteralPath $zipPath).Length }
    } finally {
        if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
    }
}

Export-ModuleMember -Function @(
    'Get-FrameGenNGManagerSettings',
    'Set-FrameGenNGAdvancedDiagnostics',
    'Set-FrameGenNGNativeDiagnosticLogging',
    'Write-FrameGenNGDiagnosticLog',
    'Get-FrameGenNGDiagnosticSummary',
    'Export-FrameGenNGDiagnosticBundle'
)
