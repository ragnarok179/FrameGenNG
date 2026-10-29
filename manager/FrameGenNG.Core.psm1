Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProductName = 'FrameGenNG'
$script:StateFileName = 'install-state.json'
$script:SettingsEnabledKey = 'BeamNGFrameGenerationEnabled'
$script:SettingsMultiplierKey = 'BeamNGFrameGenerationMultiplier'
$script:RestorePointSchemaVersion = 1
$script:AutomaticRestorePointLimit = 5
$script:ManualRestorePointLimit = 10
$script:TechnicalBackupLimit = 2
$script:RecoveryArtifactLimit = 3

function Get-FrameGenNGPackageRoot {
    return [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
}

function Get-FrameGenNGVersion {
    $versionPath = Join-Path (Get-FrameGenNGPackageRoot) 'VERSION'
    if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
        throw "VERSION file not found: $versionPath"
    }
    return (Get-Content -LiteralPath $versionPath -Raw).Trim()
}

function Assert-BeamNGClosed {
    if ($null -ne (Get-Process -Name 'BeamNG.drive.x64' -ErrorAction SilentlyContinue)) {
        throw 'BeamNG.drive is running. Close the game completely before continuing.'
    }
}

function Test-BeamNGGameRoot {
    param([Parameter(Mandatory)][string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    return Test-Path -LiteralPath (Join-Path $fullPath 'Bin64\BeamNG.drive.x64.exe') -PathType Leaf
}

function Resolve-BeamNGGameRoot {
    param([string]$GameRoot)

    if (-not [string]::IsNullOrWhiteSpace($GameRoot)) {
        $candidate = [System.IO.Path]::GetFullPath($GameRoot).TrimEnd('\')
    } else {
        $candidate = [System.IO.Path]::GetFullPath((Split-Path -Parent (Get-FrameGenNGPackageRoot))).TrimEnd('\')
    }

    if (-not (Test-BeamNGGameRoot -Path $candidate)) {
        throw @"
FrameGenNG must be placed directly in the BeamNG.drive root folder.
Expected folder: <BeamNG.drive>\FrameGenNG
Checked folder: $candidate
Expected executable: Bin64\BeamNG.drive.x64.exe
"@
    }
    return $candidate
}

function Resolve-BeamNGUserRoot {
    param([string]$LauncherIni)

    if ([string]::IsNullOrWhiteSpace($LauncherIni)) {
        $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        $LauncherIni = Join-Path $localAppData 'BeamNG\BeamNG.drive.ini'
    }
    if (-not (Test-Path -LiteralPath $LauncherIni -PathType Leaf)) {
        throw "BeamNG configuration not found: $LauncherIni. Run the BeamNG launcher at least once."
    }

    $configuredUserFolder = $null
    foreach ($line in Get-Content -LiteralPath $LauncherIni) {
        if ($line -match '^\s*userFolder\s*=\s*(.*?)\s*$') {
            $configuredUserFolder = $Matches[1].Trim().Trim('"')
            break
        }
    }

    $launcherRoot = Split-Path -Parent $LauncherIni
    if ([string]::IsNullOrWhiteSpace($configuredUserFolder)) {
        $base = Join-Path $launcherRoot 'BeamNG.drive\current'
    } else {
        $base = [Environment]::ExpandEnvironmentVariables($configuredUserFolder)
        if (-not [System.IO.Path]::IsPathRooted($base)) {
            $base = Join-Path $launcherRoot $base
        }
    }
    $base = [System.IO.Path]::GetFullPath($base).TrimEnd('\')

    $directSettings = Join-Path $base 'settings\settings.json'
    $currentRoot = Join-Path $base 'current'
    $currentSettings = Join-Path $currentRoot 'settings\settings.json'
    if (Test-Path -LiteralPath $directSettings -PathType Leaf) {
        return $base
    }
    if (Test-Path -LiteralPath $currentSettings -PathType Leaf) {
        return [System.IO.Path]::GetFullPath($currentRoot).TrimEnd('\')
    }
    throw "Invalid BeamNG user folder. No settings.json was found under $base or $currentRoot"
}

function Get-FrameGenNGGameLanguage {
    param([Parameter(Mandatory)][string]$UserRoot)

    $settingsPath = Join-Path $UserRoot 'settings\cloud\settings.json'
    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
        try {
            $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
            if ($settings.PSObject.Properties.Name -contains 'userLanguage') {
                $language = ([string]$settings.userLanguage).Trim().ToLowerInvariant()
                if ($language -match '^(fr|de|es|it|pt|pl|ru|zh|ja|ko)(?:[_-]|$)') { return $Matches[1] }
            }
        } catch {
            # Invalid or unavailable language settings must never block installation.
        }
    }
    return 'en'
}

function Get-FrameGenNGGameStrings {
    param([Parameter(Mandatory)][string]$UserRoot)

    $strings = @{
        en = @{
            Heading = 'Frame Generation'
            Enabled = 'Enable Frame Generation'
            EnabledTooltip = 'Inserts generated frames between frames rendered by the game.'
            Multiplier = 'Multiplier'
            MultiplierTooltip = '2× is recommended for the best balance of smoothness and stability.'
            Recommended = '2× — Recommended'
        }
        fr = @{
            Heading = "Génération d’images"
            Enabled = "Activer la génération d’images"
            EnabledTooltip = "Insère des images générées entre les images rendues par le jeu."
            Multiplier = "Multiplicateur"
            MultiplierTooltip = "2× est recommandé pour le meilleur équilibre entre fluidité et stabilité."
            Recommended = "2× — Recommandé"
        }
        de = @{
            Heading = 'Frame-Generierung'
            Enabled = 'Frame-Generierung aktivieren'
            EnabledTooltip = 'Fügt generierte Bilder zwischen den vom Spiel gerenderten Bildern ein.'
            Multiplier = 'Multiplikator'
            MultiplierTooltip = '2× wird für das beste Verhältnis aus Flüssigkeit und Stabilität empfohlen.'
            Recommended = '2× — Empfohlen'
        }
        es = @{
            Heading = 'Generación de fotogramas'
            Enabled = 'Activar generación de fotogramas'
            EnabledTooltip = 'Inserta fotogramas generados entre los fotogramas renderizados por el juego.'
            Multiplier = 'Multiplicador'
            MultiplierTooltip = 'Se recomienda 2× para obtener el mejor equilibrio entre fluidez y estabilidad.'
            Recommended = '2× — Recomendado'
        }
        it = @{
            Heading = 'Generazione fotogrammi'
            Enabled = 'Attiva generazione fotogrammi'
            EnabledTooltip = 'Inserisce fotogrammi generati tra quelli renderizzati dal gioco.'
            Multiplier = 'Moltiplicatore'
            MultiplierTooltip = '2× è consigliato per il miglior equilibrio tra fluidità e stabilità.'
            Recommended = '2× — Consigliato'
        }
        pt = @{
            Heading = 'Geração de quadros'
            Enabled = 'Ativar geração de quadros'
            EnabledTooltip = 'Insere quadros gerados entre os quadros renderizados pelo jogo.'
            Multiplier = 'Multiplicador'
            MultiplierTooltip = '2× é recomendado para o melhor equilíbrio entre fluidez e estabilidade.'
            Recommended = '2× — Recomendado'
        }
        pl = @{
            Heading = 'Generowanie klatek'
            Enabled = 'Włącz generowanie klatek'
            EnabledTooltip = 'Wstawia wygenerowane klatki pomiędzy klatki renderowane przez grę.'
            Multiplier = 'Mnożnik'
            MultiplierTooltip = '2× jest zalecane dla najlepszego balansu płynności i stabilności.'
            Recommended = '2× — Zalecane'
        }
        ru = @{
            Heading = 'Генерация кадров'
            Enabled = 'Включить генерацию кадров'
            EnabledTooltip = 'Вставляет сгенерированные кадры между кадрами, отрисованными игрой.'
            Multiplier = 'Множитель'
            MultiplierTooltip = 'Для оптимального баланса плавности и стабильности рекомендуется 2×.'
            Recommended = '2× — Рекомендуется'
        }
        zh = @{
            Heading = '帧生成'
            Enabled = '启用帧生成'
            EnabledTooltip = '在游戏渲染的帧之间插入生成帧。'
            Multiplier = '倍数'
            MultiplierTooltip = '建议使用 2×，以获得流畅度和稳定性的最佳平衡。'
            Recommended = '2× — 推荐'
        }
        ja = @{
            Heading = 'フレーム生成'
            Enabled = 'フレーム生成を有効にする'
            EnabledTooltip = 'ゲームがレンダリングしたフレームの間に生成フレームを挿入します。'
            Multiplier = '倍率'
            MultiplierTooltip = '滑らかさと安定性のバランスには 2× を推奨します。'
            Recommended = '2× — 推奨'
        }
        ko = @{
            Heading = '프레임 생성'
            Enabled = '프레임 생성 활성화'
            EnabledTooltip = '게임에서 렌더링한 프레임 사이에 생성된 프레임을 삽입합니다.'
            Multiplier = '배율'
            MultiplierTooltip = '부드러움과 안정성의 균형을 위해 2×를 권장합니다.'
            Recommended = '2× — 권장'
        }
    }
    return $strings[(Get-FrameGenNGGameLanguage -UserRoot $UserRoot)]
}

function Get-FrameGenNGDataRoot {
    param([Parameter(Mandatory)][string]$UserRoot)
    return Join-Path $UserRoot 'FrameGenNG'
}

function Get-FrameGenNGStatePath {
    param([Parameter(Mandatory)][string]$UserRoot)
    return Join-Path (Get-FrameGenNGDataRoot -UserRoot $UserRoot) $script:StateFileName
}

. (Join-Path $PSScriptRoot 'Core\FrameGenNG.Recovery.ps1')

function Get-BeamNGLauncherIniPath {
    param([string]$LauncherIni)
    if (-not [string]::IsNullOrWhiteSpace($LauncherIni)) {
        return [System.IO.Path]::GetFullPath($LauncherIni)
    }
    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    return Join-Path $localAppData 'BeamNG\BeamNG.drive.ini'
}

function Get-BeamNGIdentity {
    param(
        [Parameter(Mandatory)][string]$GameRoot,
        [string]$LauncherIni
    )
    $executable = Join-Path $GameRoot 'Bin64\BeamNG.drive.x64.exe'
    $version = $null
    $launcherPath = Get-BeamNGLauncherIniPath -LauncherIni $LauncherIni
    if (Test-Path -LiteralPath $launcherPath -PathType Leaf) {
        foreach ($line in Get-Content -LiteralPath $launcherPath) {
            if ($line -match '^\s*version\s*=\s*(.+?)\s*$') {
                $version = $Matches[1].Trim().Trim('"')
                break
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = [string](Get-Item -LiteralPath $executable).VersionInfo.FileVersion
    }
    if ([string]::IsNullOrWhiteSpace($version)) { $version = 'unknown' }
    return [pscustomobject][ordered]@{
        version = $version
        executable = [System.IO.Path]::GetFullPath($executable)
        executableSha256 = Get-FileSha256 -Path $executable
    }
}

function Read-FrameGenNGState {
    param(
        [Parameter(Mandatory)][string]$UserRoot,
        [switch]$AllowBackup
    )
    $primary = Get-FrameGenNGStatePath -UserRoot $UserRoot
    $candidates = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $primary -PathType Leaf) { $candidates.Add($primary) }
    if ($AllowBackup) {
        $backupRoot = Join-Path (Get-FrameGenNGDataRoot -UserRoot $UserRoot) 'backups'
        if (Test-Path -LiteralPath $backupRoot -PathType Container) {
            foreach ($file in Get-ChildItem -LiteralPath $backupRoot -Filter 'installation-state.json' -Recurse -File -Force | Sort-Object LastWriteTime -Descending) {
                $candidates.Add($file.FullName)
            }
        }
    }
    foreach ($candidate in $candidates) {
        try {
            $state = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json
            if ([string]$state.product -eq $script:ProductName -and $state.PSObject.Properties.Name -contains 'targets') {
                return [pscustomobject]@{ state = $state; path = $candidate; primaryPath = $primary; recovered = ($candidate -ne $primary) }
            }
        } catch {
            # Continue to the redundant state copy when the primary file is damaged.
        }
    }
    return $null
}

function Assert-FrameGenNGPayloadIntegrity {
    param([Parameter(Mandatory)][string]$PackageRoot)
    $manifestPath = Join-Path $PackageRoot 'payload\manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Payload manifest not found: $manifestPath" }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $packageVersion = (Get-Content -LiteralPath (Join-Path $PackageRoot 'VERSION') -Raw).Trim()
    if ([string]$manifest.packageVersion -ne $packageVersion) {
        throw "Payload manifest version $($manifest.packageVersion) does not match package version $packageVersion."
    }
    foreach ($entry in @($manifest.files)) {
        $relative = ([string]$entry.path).Replace('/', '\')
        $path = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PackageRoot 'payload') $relative))
        if (-not (Test-PathUnderRoot -Path $path -Roots @((Join-Path $PackageRoot 'payload')))) { throw "Unsafe payload path: $relative" }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Payload file is missing: $relative" }
        if ((Get-Item -LiteralPath $path).Length -ne [long]$entry.size) { throw "Payload size mismatch: $relative" }
        if ((Get-FileSha256 -Path $path) -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "Payload checksum mismatch: $relative" }
    }
    return $manifest
}

function Get-NvidiaSmiPath {
    $candidates = @(
        (Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'),
        (Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }

    $command = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    return $null
}

function Get-NvidiaRtxAdaptersFromDriver {
    $nvidiaSmi = Get-NvidiaSmiPath
    if ([string]::IsNullOrWhiteSpace([string]$nvidiaSmi)) { return @() }

    try {
        $output = @(& $nvidiaSmi '--query-gpu=name,compute_cap' '--format=csv,noheader' 2>$null)
        if ($LASTEXITCODE -ne 0) { return @() }
    } catch {
        return @()
    }

    $adapters = foreach ($line in $output) {
        $match = [regex]::Match([string]$line, '^(?<name>.+),\s*(?<capability>\d+\.\d+)\s*$')
        if ($match.Success -and $match.Groups['name'].Value -match '(?i)\bRTX\b') {
            [pscustomobject]@{
                Name = $match.Groups['name'].Value.Trim()
                ComputeCapability = $match.Groups['capability'].Value
            }
        }
    }
    return @($adapters)
}

function Resolve-NvidiaRtxAdapterProfile {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$ComputeCapability
    )

    if ($Name -notmatch '(?i)\bRTX\b') { return $null }

    if (-not [string]::IsNullOrWhiteSpace($ComputeCapability)) {
        switch ($ComputeCapability.Trim()) {
            '7.5' { return [pscustomobject]@{ Profile = 'LegacyRTX'; Gpu = $Name } }
            '8.6' { return [pscustomobject]@{ Profile = 'LegacyRTX'; Gpu = $Name } }
            '8.9' { return [pscustomobject]@{ Profile = 'NativeRTX'; Gpu = $Name } }
            '12.0' { return [pscustomobject]@{ Profile = 'NativeRTX'; Gpu = $Name } }
            default { return $null }
        }
    }

    if ($Name -match '(?i)\b(Ada(?:\s+Lovelace)?|Blackwell)\b') {
        return [pscustomobject]@{ Profile = 'NativeRTX'; Gpu = $Name }
    }
    if ($Name -match '(?i)\b(Turing|Ampere)\b') {
        return [pscustomobject]@{ Profile = 'LegacyRTX'; Gpu = $Name }
    }
    if ($Name -match '(?i)\bGeForce\s+RTX\s+(20|30)\d{2}\b' -or
        $Name -match '(?i)\bRTX\s+A\d{3,4}\b' -or
        $Name -match '(?i)\bQuadro\s+RTX\b' -or
        $Name -match '(?i)\bTITAN\s+RTX\b') {
        return [pscustomobject]@{ Profile = 'LegacyRTX'; Gpu = $Name }
    }
    if ($Name -match '(?i)\bGeForce\s+RTX\s+(40|50)\d{2}\b') {
        return [pscustomobject]@{ Profile = 'NativeRTX'; Gpu = $Name }
    }
    return $null
}

function Select-NvidiaRtxProfile {
    param([Parameter(Mandatory)][object[]]$Adapters)

    $resolved = @($Adapters | ForEach-Object {
        Resolve-NvidiaRtxAdapterProfile -Name ([string]$_.Name) -ComputeCapability ([string]$_.ComputeCapability)
    } | Where-Object { $null -ne $_ })
    if ($resolved.Count -ne $Adapters.Count) {
        $descriptions = @($Adapters | ForEach-Object {
            $capability = if ([string]::IsNullOrWhiteSpace([string]$_.ComputeCapability)) { 'unknown architecture' } else { "SM $($_.ComputeCapability)" }
            "$($_.Name) ($capability)"
        })
        throw "Unsupported or unvalidated NVIDIA RTX architecture: $($descriptions -join ', '). Supported compute capabilities are 7.5, 8.6, 8.9, and 12.0."
    }

    $profiles = @($resolved | Select-Object -ExpandProperty Profile -Unique)
    if ($profiles.Count -ne 1) {
        throw "Multiple NVIDIA RTX architecture generations were detected. Use -Profile LegacyRTX or -Profile NativeRTX to select the GPU used by BeamNG."
    }
    return $resolved[0]
}

function Get-NvidiaRtxProfile {
    param([ValidateSet('Auto', 'LegacyRTX', 'NativeRTX')][string]$Profile = 'Auto')

    if ($Profile -ne 'Auto') {
        return [pscustomobject]@{ Profile = $Profile; Gpu = 'Profile forced from the command line' }
    }

    $driverAdapters = @(Get-NvidiaRtxAdaptersFromDriver)
    if ($driverAdapters.Count -gt 0) {
        return Select-NvidiaRtxProfile -Adapters $driverAdapters
    }

    try {
        $gpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object { [string]$_.Name })
    } catch {
        throw "Unable to detect the GPU. Use -Profile LegacyRTX or -Profile NativeRTX. Details: $($_.Exception.Message)"
    }
    $rtxAdapters = @($gpuNames | Where-Object { $_ -match '(?i)NVIDIA.*\bRTX\b' } | ForEach-Object {
        [pscustomobject]@{ Name = $_; ComputeCapability = $null }
    })
    if ($rtxAdapters.Count -eq 0) {
        throw "No NVIDIA RTX GPU was detected. GPUs found: $($gpuNames -join ', ')"
    }
    return Select-NvidiaRtxProfile -Adapters $rtxAdapters
}

function Get-FileSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-MutableRuntimeFile {
    param([Parameter(Mandatory)][string]$RelativePath)

    return $RelativePath.Replace('\', '/').StartsWith('logs/', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-DirectorySha256 {
    param([Parameter(Mandatory)][string]$Path)

    $root = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $lines = foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force | Sort-Object FullName) {
        $relativePath = $file.FullName.Substring($root.Length).TrimStart('\').Replace('\', '/')
        if (-not (Test-MutableRuntimeFile -RelativePath $relativePath)) {
            "$($relativePath.ToLowerInvariant())|$(Get-FileSha256 -Path $file.FullName)"
        }
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-DirectoryFileRecords {
    param([Parameter(Mandatory)][string]$Path)

    $root = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    return @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
        [pscustomobject][ordered]@{
            relativePath = $_.FullName.Substring($root.Length).TrimStart('\').Replace('\', '/')
            sha256 = Get-FileSha256 -Path $_.FullName
        }
    })
}

function Test-InstalledDirectoryFiles {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$InstalledFiles
    )

    $expectedFiles = @($InstalledFiles | Where-Object {
        -not (Test-MutableRuntimeFile -RelativePath ([string]$_.relativePath))
    })
    $currentFiles = @(Get-DirectoryFileRecords -Path $Path | Where-Object {
        -not (Test-MutableRuntimeFile -RelativePath ([string]$_.relativePath))
    })
    if ($currentFiles.Count -ne $expectedFiles.Count) {
        return $false
    }

    $currentHashes = [System.Collections.Generic.Dictionary[string, string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($file in $currentFiles) {
        $currentHashes[[string]$file.relativePath] = [string]$file.sha256
    }
    foreach ($file in $expectedFiles) {
        $relativePath = [string]$file.relativePath
        if (-not $currentHashes.ContainsKey($relativePath) -or
            $currentHashes[$relativePath] -ne [string]$file.sha256) {
            return $false
        }
    }
    return $true
}

function Get-IniSettings {
    param([Parameter(Mandatory)][string]$Path)

    $settings = [System.Collections.Generic.Dictionary[string, string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $section = ''
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmedLine = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmedLine) -or
            $trimmedLine.StartsWith(';') -or
            $trimmedLine.StartsWith('#')) {
            continue
        }
        if ($trimmedLine -match '^\[(.+)\]$') {
            $section = $Matches[1].Trim()
        } elseif ($trimmedLine -match '^([^=]+)=(.*)$') {
            $qualifiedKey = "$section`n$($Matches[1].Trim())"
            $settings[$qualifiedKey] = $Matches[2].Trim()
        }
    }
    return $settings
}

function Test-IniSemanticMatch {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ReferencePath
    )

    $currentSettings = Get-IniSettings -Path $Path
    $requiredSettings = Get-IniSettings -Path $ReferencePath
    foreach ($requiredSetting in $requiredSettings.GetEnumerator()) {
        if (-not $currentSettings.ContainsKey($requiredSetting.Key) -or
            $currentSettings[$requiredSetting.Key] -cne $requiredSetting.Value) {
            return $false
        }
    }
    return $true
}

function Get-PathSha256 {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return Get-FileSha256 -Path $Path }
    if (Test-Path -LiteralPath $Path -PathType Container) { return Get-DirectorySha256 -Path $Path }
    return $null
}

function Test-PathUnderRoot {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Roots
    )
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    foreach ($root in $Roots) {
        $allowed = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
        if ($full.Equals($allowed, [System.StringComparison]::OrdinalIgnoreCase) -or
            $full.StartsWith($allowed + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Clear-BeamNGShaderCache {
    param([Parameter(Mandatory)][string]$UserRoot)

    $tempRoot = [System.IO.Path]::GetFullPath((Join-Path $UserRoot 'temp')).TrimEnd('\')
    $shaderCachePath = [System.IO.Path]::GetFullPath((Join-Path $tempRoot 'shaders')).TrimEnd('\')
    if (-not (Test-PathUnderRoot -Path $shaderCachePath -Roots @($tempRoot))) {
        throw "Shader cache is outside the BeamNG temporary folder: $shaderCachePath"
    }
    if (Test-Path -LiteralPath $shaderCachePath -PathType Container) {
        Remove-Item -LiteralPath $shaderCachePath -Recurse -Force
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Path,
        [int]$Depth = 20
    )
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $json = $Value | ConvertTo-Json -Depth $Depth
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Copy-TargetWithBackup {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$BackupRoot,
        [Parameter(Mandatory)][int]$Index
    )
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Package file is missing: $Source"
    }

    $isDirectory = Test-Path -LiteralPath $Source -PathType Container
    $existed = Test-Path -LiteralPath $Destination
    $backupName = ('target-{0:d3}' -f $Index)
    $backupPath = Join-Path $BackupRoot $backupName
    $originalHash = $null
    if ($existed) {
        $originalHash = Get-PathSha256 -Path $Destination
        Copy-Item -LiteralPath $Destination -Destination $backupPath -Recurse -Force
    }

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force

    return [pscustomobject][ordered]@{
        destination = [System.IO.Path]::GetFullPath($Destination)
        existed = $existed
        backupName = $backupName
        isDirectory = $isDirectory
        originalSha256 = $originalHash
        installedSha256 = Get-PathSha256 -Path $Destination
        installedFiles = if ($isDirectory) { Get-DirectoryFileRecords -Path $Destination } else { $null }
    }
}

function Backup-WritableTarget {
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$BackupRoot,
        [Parameter(Mandatory)][int]$Index
    )
    $existed = Test-Path -LiteralPath $Destination
    $backupName = ('target-{0:d3}' -f $Index)
    $originalHash = $null
    if ($existed) {
        $originalHash = Get-PathSha256 -Path $Destination
        Copy-Item -LiteralPath $Destination -Destination (Join-Path $BackupRoot $backupName) -Recurse -Force
    }
    return [pscustomobject][ordered]@{
        destination = [System.IO.Path]::GetFullPath($Destination)
        existed = $existed
        backupName = $backupName
        isDirectory = $false
        originalSha256 = $originalHash
        installedSha256 = $null
    }
}

function Restore-TrackedTarget {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$BackupRoot,
        [Parameter(Mandatory)][string[]]$AllowedRoots,
        [string]$RecoveryRoot,
        [string]$GameRoot
    )
    $destination = [System.IO.Path]::GetFullPath([string]$Target.destination)
    if (-not (Test-PathUnderRoot -Path $destination -Roots $AllowedRoots)) {
        throw "Restore target is outside the allowed folders: $destination"
    }

    $isGameTarget = -not [string]::IsNullOrWhiteSpace($GameRoot) -and
        (Test-PathUnderRoot -Path $destination -Roots @($GameRoot))
    $isPreExistingGameFile = $isGameTarget -and [bool]$Target.existed
    if (Test-Path -LiteralPath $destination) {
        $currentHash = Get-PathSha256 -Path $destination
        $installedHash = [string]$Target.installedSha256
        $changedOutsideFrameGenNG = -not [string]::IsNullOrWhiteSpace($installedHash) -and
            $currentHash -ne $installedHash
        if ($changedOutsideFrameGenNG -and -not [string]::IsNullOrWhiteSpace($RecoveryRoot)) {
            New-Item -ItemType Directory -Path $RecoveryRoot -Force | Out-Null
            Copy-Item -LiteralPath $destination -Destination (Join-Path $RecoveryRoot ([string]$Target.backupName)) -Recurse -Force
        }
        if ($isPreExistingGameFile -and $changedOutsideFrameGenNG) {
            return
        }
        Remove-Item -LiteralPath $destination -Recurse -Force
    } elseif ($isPreExistingGameFile) {
        # Absence can be the current vanilla state after a game update. Never restore an old game file blindly.
        return
    }

    if ([bool]$Target.existed) {
        $source = Join-Path $BackupRoot ([string]$Target.backupName)
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Original backup is missing: $source"
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
}

function Get-GraphicsLayoutPatch {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$UserRoot
    )
    $layout = Get-Content -LiteralPath $SourcePath -Raw | ConvertFrom-Json
    $text = Get-FrameGenNGGameStrings -UserRoot $UserRoot
    $graphics = @($layout.items | Where-Object {
        $_.PSObject.Properties.Name -contains 'categoryId' -and $_.categoryId -eq 'graphics'
    })
    if ($graphics.Count -ne 1) { throw "BeamNG graphics category is missing or ambiguous: $($graphics.Count)" }

    $groups = @($graphics[0].items | Where-Object {
        $_.PSObject.Properties.Name -contains 'items' -and
        @($_.items | Where-Object { $_.PSObject.Properties.Name -contains 'setting' -and $_.setting -eq 'GraphicAntialiasType' }).Count -eq 1
    })
    if ($groups.Count -ne 1) { throw "BeamNG DLSS group is missing or ambiguous: $($groups.Count)" }

    $alreadyPatched = @($groups[0].items | Where-Object {
        $_.PSObject.Properties.Name -contains 'setting' -and $_.setting -eq $script:SettingsEnabledKey
    }).Count -gt 0
    if ($alreadyPatched) { return $layout }

    $fgItems = @(
        [pscustomobject][ordered]@{
            version = '0.40'; label = $text.Heading; interactive = $false
            condition_always_off = $false; condition_not_shipping = $false; condition_simplemenu = ''
            condition_visible = 'GraphicDLSSSelected'; condition_enabled = ''; itemType = 'heading'
            component = 'OptionsHeading'; icon = '_empty'; variant = 'h4'; search = @('label')
        },
        [pscustomobject][ordered]@{
            version = '0.40'; label = $text.Enabled
            tooltip = $text.EnabledTooltip
            setting = $script:SettingsEnabledKey; interactive = $true; condition_always_off = $false
            condition_not_shipping = $false; condition_simplemenu = ''; condition_visible = 'GraphicDLSSSelected'
            condition_enabled = ''; itemType = 'checkbox'; component = 'OptionsCheckbox'; separateLabel = $true
            manualApply = $false; manualLua = ''; lua = ''; luaOff = ''; valueOn = $true; valueOff = $false
            search = @('label', 'caption', 'tooltip', 'setting')
        },
        [pscustomobject][ordered]@{
            version = '0.40'; label = $text.Multiplier
            tooltip = $text.MultiplierTooltip
            setting = $script:SettingsMultiplierKey; interactive = $true; condition_always_off = $false
            condition_not_shipping = $false; condition_simplemenu = ''; condition_visible = 'GraphicDLSSSelected'
            condition_enabled = $script:SettingsEnabledKey; itemType = 'options'; component = 'BngSmartSelect'
            separateLabel = $true; manualApply = $false; manualLua = ''; optionsSource = ''
            options = @(
                [pscustomobject][ordered]@{ value = 2; label = $text.Recommended },
                [pscustomobject][ordered]@{ value = 3; label = '3×' },
                [pscustomobject][ordered]@{ value = 4; label = '4×' }
            )
            lua = ''; basic_interaction = $false
            search = @('label', 'caption', 'tooltip', 'setting', 'optionsSource', 'options')
        }
    )

    $newItems = [System.Collections.Generic.List[object]]::new()
    $inserted = $false
    foreach ($item in @($groups[0].items)) {
        $newItems.Add($item)
        if (-not $inserted -and $item.PSObject.Properties.Name -contains 'setting' -and
            $item.setting -eq 'GraphicUpscalingSharpness') {
            foreach ($fgItem in $fgItems) { $newItems.Add($fgItem) }
            $inserted = $true
        }
    }
    if (-not $inserted) { throw 'Unable to find the FrameGenNG control insertion point after the DLSS settings.' }
    $groups[0].items = $newItems.ToArray()
    return $layout
}

function Get-ConditionsPatch {
    param([Parameter(Mandatory)][string]$SourcePath)
    $conditions = Get-Content -LiteralPath $SourcePath -Raw
    if ($conditions -match '\bGraphicDLSSSelected\s*\(') { return $conditions }
    $anchor = '(?ms)(    GraphicAntialiasEnabled\(values\) \{\r?\n      return values\.GraphicAntialiasType !== "off"\r?\n    \},)'
    if ($conditions -notmatch $anchor) { throw 'Unable to find the DLSS condition insertion point.' }
    $addition = @'
$1
    GraphicDLSSSelected(values) {
      return values.GraphicAntialiasType === "dlss"
    },
'@
    return [regex]::Replace($conditions, $anchor, $addition, 1)
}

function Get-HdrEncoderPatch {
    param([Parameter(Mandatory)][string]$SourcePath)

    $source = [System.IO.File]::ReadAllText($SourcePath)
    $originalScRgbConstant = 'static const uint OutputMode_scRGB = 1;'
    $originalHdr10Constant = 'static const uint OutputMode_HDR10 = 2;'
    $hdr10Comparison = 'outputMode == OutputMode_HDR10'

    if ($source.Contains('FrameGenNGIsHdr10Output')) {
        throw "The BeamNG HDR encoder already contains a FrameGenNG bridge: $SourcePath"
    }
    if (-not $source.Contains($originalScRgbConstant) -or
        -not $source.Contains($originalHdr10Constant) -or
        -not $source.Contains($hdr10Comparison)) {
        throw "Unsupported BeamNG HDR encoder version: $SourcePath"
    }

    $bridge = @'
static const uint OutputMode_scRGB = 0xFFFFFFFEu;
static const uint OutputMode_HDR10 = 1;
static const uint OutputMode_HDR10Native = 2;

// FrameGenNG keeps BeamNG mode 1 aligned with its HDR10 swapchain bridge.
bool FrameGenNGIsHdr10Output(uint outputMode)
{
   return outputMode == OutputMode_HDR10 || outputMode == OutputMode_HDR10Native;
}
'@

    $patched = $source.Replace($hdr10Comparison, 'FrameGenNGIsHdr10Output(outputMode)')
    $patched = $patched.Replace($originalScRgbConstant, $bridge)
    $patched = $patched.Replace($originalHdr10Constant, '')
    return $patched
}

function Get-OriginalSettingState {
    param([Parameter(Mandatory)]$Settings, [Parameter(Mandatory)][string]$Name)
    $exists = $Settings.PSObject.Properties.Name -contains $Name
    return [pscustomobject][ordered]@{
        name = $Name
        existed = $exists
        value = if ($exists) { $Settings.$Name } else { $null }
    }
}

function Restore-SettingState {
    param([Parameter(Mandatory)]$Settings, [Parameter(Mandatory)]$State)
    $name = [string]$State.name
    if ([bool]$State.existed) {
        $Settings | Add-Member -NotePropertyName $name -NotePropertyValue $State.value -Force
    } else {
        $Settings.PSObject.Properties.Remove($name)
    }
}

function New-FrameGenNGInstallationPlan {
    param(
        [Parameter(Mandatory)][string]$PackageRoot,
        [Parameter(Mandatory)][string]$GameRoot,
        [Parameter(Mandatory)][string]$UserRoot,
        [Parameter(Mandatory)][ValidateSet('LegacyRTX', 'NativeRTX')][string]$Profile
    )

    $payloadBin = Join-Path $PackageRoot 'payload\Bin64'
    $gameBin = Join-Path $GameRoot 'Bin64'
    $nativeItems = @(
        [pscustomobject]@{ Source = Join-Path $payloadBin 'dxgi.dll'; Destination = Join-Path $gameBin 'dxgi.dll' },
        [pscustomobject]@{ Source = Join-Path $payloadBin 'FrameGenNG.ini'; Destination = Join-Path $gameBin 'FrameGenNG.ini' },
        [pscustomobject]@{ Source = Join-Path $payloadBin 'FrameGenNG'; Destination = Join-Path $gameBin 'FrameGenNG' }
    )
    if ($Profile -eq 'LegacyRTX') {
        $nativeItems += @(
            [pscustomobject]@{ Source = Join-Path $payloadBin 'd3d12.dll'; Destination = Join-Path $gameBin 'd3d12.dll' },
            [pscustomobject]@{ Source = Join-Path $payloadBin 'FGNGEngine.ini'; Destination = Join-Path $gameBin 'FGNGEngine.ini' },
            [pscustomobject]@{ Source = Join-Path $payloadBin 'FGNGEngine'; Destination = Join-Path $gameBin 'FGNGEngine' }
        )
    }

    $lifecycleRoot = Join-Path $UserRoot 'mods\unpacked\FrameGenNG'
    $lifecycleItems = @(
        [pscustomobject]@{
            Source = Join-Path $PackageRoot 'payload\user-mod\scripts\frameGenNG\modScript.lua'
            Destination = Join-Path $lifecycleRoot 'scripts\frameGenNG\modScript.lua'
        },
        [pscustomobject]@{
            Source = Join-Path $PackageRoot 'payload\user-mod\lua\ge\extensions\frameGenNGLifecycle.lua'
            Destination = Join-Path $lifecycleRoot 'lua\ge\extensions\frameGenNGLifecycle.lua'
        }
    )

    return [pscustomobject][ordered]@{
        NativeItems = $nativeItems
        LifecycleItems = $lifecycleItems
        LayoutSource = Join-Path $GameRoot 'ui\ui-vue\src\modules\options\runtime\layout.json'
        ConditionsSource = Join-Path $GameRoot 'ui\ui-vue\src\modules\options\runtime\conditions.js'
        LayoutTarget = Join-Path $UserRoot 'ui\ui-vue\src\modules\options\runtime\layout.json'
        ConditionsTarget = Join-Path $UserRoot 'ui\ui-vue\src\modules\options\runtime\conditions.js'
        HdrEncoderSource = Join-Path $GameRoot 'shaders\common\postFx\hdr\hdrEncode.h.hlsl'
        HdrEncoderTarget = Join-Path $UserRoot 'shaders\common\postFx\hdr\hdrEncode.h.hlsl'
        SettingsPath = Join-Path $UserRoot 'settings\settings.json'
    }
}

function Test-FrameGenNGRuntimeConfigFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $signature = '; FrameGenNG production configuration for BeamNG.drive.'
    return (Get-Content -LiteralPath $Path -TotalCount 1) -ceq $signature
}

function Remove-ValidatedLegacyUpdateResidue {
    param([Parameter(Mandatory)]$Plan)

    foreach ($nativeItem in @($Plan.NativeItems)) {
        $destination = [string]$nativeItem.Destination
        if (-not (Test-Path -LiteralPath $destination)) { continue }

        $name = [System.IO.Path]::GetFileName($destination)
        $isOwnedRuntimeConfig = $name.Equals(
            'FrameGenNG.ini',
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and (Test-FrameGenNGRuntimeConfigFile -Path $destination)
        $isOwnedEngineDirectory = $name.Equals(
            'FGNGEngine',
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and (Test-Path -LiteralPath $destination -PathType Container) -and
            (Test-InstalledDirectoryFiles -Path $destination -InstalledFiles (
                Get-DirectoryFileRecords -Path ([string]$nativeItem.Source)
            ))

        if ($isOwnedRuntimeConfig -or $isOwnedEngineDirectory) {
            Remove-Item -LiteralPath $destination -Recurse -Force
        }
    }
}

function Assert-FrameGenNGInstallationPlan {
    param([Parameter(Mandatory)]$Plan)

    foreach ($nativeItem in @($Plan.NativeItems)) {
        if (Test-Path -LiteralPath $nativeItem.Destination) {
            throw "A conflicting third-party file already exists: $($nativeItem.Destination). Remove the other graphics mod or restore BeamNG before installing FrameGenNG."
        }
    }

    if (Test-Path -LiteralPath $Plan.HdrEncoderTarget) {
        throw "A conflicting HDR shader override already exists: $($Plan.HdrEncoderTarget)"
    }

    $requiredPaths = @($Plan.LayoutSource, $Plan.ConditionsSource, $Plan.HdrEncoderSource, $Plan.SettingsPath) +
        @($Plan.NativeItems.Source) + @($Plan.LifecycleItems.Source)
    foreach ($requiredPath in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $requiredPath)) { throw "Required file not found: $requiredPath" }
    }
}

function Install-FrameGenNG {
    [CmdletBinding()]
    param(
        [string]$GameRoot,
        [string]$LauncherIni,
        [ValidateSet('Auto', 'LegacyRTX', 'NativeRTX')][string]$Profile = 'Auto',
        [switch]$SkipRestorePoint
    )

    Assert-BeamNGClosed
    $packageRoot = Get-FrameGenNGPackageRoot
    $gameRootResolved = Resolve-BeamNGGameRoot -GameRoot $GameRoot
    $userRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
    $payloadManifest = Assert-FrameGenNGPayloadIntegrity -PackageRoot $packageRoot
    $gameIdentity = Get-BeamNGIdentity -GameRoot $gameRootResolved -LauncherIni $LauncherIni
    $statePath = Get-FrameGenNGStatePath -UserRoot $userRoot
    if ($null -ne (Read-FrameGenNGState -UserRoot $userRoot -AllowBackup)) {
        throw 'FrameGenNG is already installed. Use Reinstall after BeamNG update or Uninstall.'
    }

    $gpu = Get-NvidiaRtxProfile -Profile $Profile
    $installationPlan = New-FrameGenNGInstallationPlan -PackageRoot $packageRoot -GameRoot $gameRootResolved -UserRoot $userRoot -Profile $gpu.Profile
    Remove-ValidatedLegacyUpdateResidue -Plan $installationPlan
    Assert-FrameGenNGInstallationPlan -Plan $installationPlan
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dataRoot = Get-FrameGenNGDataRoot -UserRoot $userRoot
    $backupRoot = Join-Path $dataRoot "backups\$timestamp"
    $redundantStatePath = Join-Path $backupRoot 'installation-state.json'

    $nativeItems = @($installationPlan.NativeItems)
    $lifecycleTargets = @($installationPlan.LifecycleItems)
    $layoutSource = [string]$installationPlan.LayoutSource
    $conditionsSource = [string]$installationPlan.ConditionsSource
    $layoutTarget = [string]$installationPlan.LayoutTarget
    $conditionsTarget = [string]$installationPlan.ConditionsTarget
    $hdrEncoderSource = [string]$installationPlan.HdrEncoderSource
    $hdrEncoderTarget = [string]$installationPlan.HdrEncoderTarget
    $settingsPath = [string]$installationPlan.SettingsPath
    if (-not $SkipRestorePoint) {
        New-FrameGenNGRestorePoint -UserRoot $userRoot -Reason 'before-install' -GameRoot $gameRootResolved -LauncherIni $LauncherIni | Out-Null
    }
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    $targets = [System.Collections.Generic.List[object]]::new()
    $settingsState = $null
    try {
        $index = 0
        foreach ($item in $nativeItems) {
            $targets.Add((Copy-TargetWithBackup -Source $item.Source -Destination $item.Destination -BackupRoot $backupRoot -Index $index))
            $index++
        }

        $hdrEncoderRecord = Backup-WritableTarget -Destination $hdrEncoderTarget -BackupRoot $backupRoot -Index $index
        $targets.Add($hdrEncoderRecord); $index++
        $patchedHdrEncoder = Get-HdrEncoderPatch -SourcePath $hdrEncoderSource
        New-Item -ItemType Directory -Path (Split-Path -Parent $hdrEncoderTarget) -Force | Out-Null
        [System.IO.File]::WriteAllText($hdrEncoderTarget, $patchedHdrEncoder, [System.Text.UTF8Encoding]::new($false))
        $hdrEncoderRecord.installedSha256 = Get-PathSha256 -Path $hdrEncoderTarget

        $layoutRecord = Backup-WritableTarget -Destination $layoutTarget -BackupRoot $backupRoot -Index $index
        $targets.Add($layoutRecord); $index++
        $layoutBase = if (Test-Path -LiteralPath $layoutTarget -PathType Leaf) { $layoutTarget } else { $layoutSource }
        $patchedLayout = Get-GraphicsLayoutPatch -SourcePath $layoutBase -UserRoot $userRoot
        Write-JsonFile -Value $patchedLayout -Path $layoutTarget -Depth 100
        $layoutRecord.installedSha256 = Get-PathSha256 -Path $layoutTarget

        $conditionsRecord = Backup-WritableTarget -Destination $conditionsTarget -BackupRoot $backupRoot -Index $index
        $targets.Add($conditionsRecord); $index++
        New-Item -ItemType Directory -Path (Split-Path -Parent $conditionsTarget) -Force | Out-Null
        $conditionsBase = if (Test-Path -LiteralPath $conditionsTarget -PathType Leaf) { $conditionsTarget } else { $conditionsSource }
        [System.IO.File]::WriteAllText($conditionsTarget, (Get-ConditionsPatch -SourcePath $conditionsBase), [System.Text.UTF8Encoding]::new($false))
        $conditionsRecord.installedSha256 = Get-PathSha256 -Path $conditionsTarget

        foreach ($item in $lifecycleTargets) {
            $targets.Add((Copy-TargetWithBackup -Source $item.Source -Destination $item.Destination -BackupRoot $backupRoot -Index $index))
            $index++
        }

        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $settingsState = @(
            Get-OriginalSettingState -Settings $settings -Name $script:SettingsEnabledKey
            Get-OriginalSettingState -Settings $settings -Name $script:SettingsMultiplierKey
        )
        $settings | Add-Member -NotePropertyName $script:SettingsEnabledKey -NotePropertyValue $true -Force
        $settings | Add-Member -NotePropertyName $script:SettingsMultiplierKey -NotePropertyValue 2 -Force
        Write-JsonFile -Value $settings -Path $settingsPath -Depth 100
        Clear-BeamNGShaderCache -UserRoot $userRoot

        $state = [pscustomobject][ordered]@{
            schemaVersion = 4
            product = $script:ProductName
            version = Get-FrameGenNGVersion
            installedAt = (Get-Date).ToString('o')
            gameRoot = $gameRootResolved
            userRoot = $userRoot
            gpu = [string]$gpu.Gpu
            profile = [string]$gpu.Profile
            gameIdentity = $gameIdentity
            gameUiSources = [pscustomobject][ordered]@{
                layoutSha256 = Get-FileSha256 -Path $layoutSource
                conditionsSha256 = Get-FileSha256 -Path $conditionsSource
            }
            payloadManifestSha256 = Get-FileSha256 -Path (Join-Path $packageRoot 'payload\manifest.json')
            backupRoot = $backupRoot
            targets = $targets.ToArray()
            settingsPath = $settingsPath
            settings = $settingsState
        }
        Write-JsonFile -Value $state -Path $redundantStatePath -Depth 30
        Write-JsonFile -Value $state -Path $statePath -Depth 30
        Invoke-FrameGenNGTechnicalBackupRetention -UserRoot $userRoot -ActiveBackupRoot $backupRoot
        return $state
    } catch {
        $installError = $_.Exception.Message
        $rollbackError = $null
        try {
            $reverseTargets = @($targets.ToArray())
            [array]::Reverse($reverseTargets)
            foreach ($target in $reverseTargets) {
                Restore-TrackedTarget -Target $target -BackupRoot $backupRoot -AllowedRoots @($gameRootResolved, $userRoot) -GameRoot $gameRootResolved
            }
            if ($null -ne $settingsState -and (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
                $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
                foreach ($entry in $settingsState) { Restore-SettingState -Settings $settings -State $entry }
                Write-JsonFile -Value $settings -Path $settingsPath -Depth 100
            }
        } catch { $rollbackError = $_.Exception.Message }
        if ($null -ne $rollbackError) {
            throw "Installation stopped: $installError. Rollback also failed: $rollbackError"
        }
        if (Test-Path -LiteralPath $redundantStatePath -PathType Leaf) { Remove-Item -LiteralPath $redundantStatePath -Force }
        throw $installError
    }
}

function Uninstall-FrameGenNG {
    [CmdletBinding()]
    param([string]$GameRoot, [string]$LauncherIni, [switch]$SkipRestorePoint)

    Assert-BeamNGClosed
    $gameRootResolved = Resolve-BeamNGGameRoot -GameRoot $GameRoot
    $userRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
    $statePath = Get-FrameGenNGStatePath -UserRoot $userRoot
    $stateRecord = Read-FrameGenNGState -UserRoot $userRoot -AllowBackup
    if ($null -eq $stateRecord) {
        throw 'No FrameGenNG installation state was found.'
    }
    $state = $stateRecord.state
    if ([string]$state.product -ne $script:ProductName) { throw 'The installation state does not belong to FrameGenNG.' }
    if ([System.IO.Path]::GetFullPath([string]$state.gameRoot).TrimEnd('\') -ne $gameRootResolved) {
        throw "The recorded installation belongs to a different BeamNG folder: $($state.gameRoot)"
    }
    if ([System.IO.Path]::GetFullPath([string]$state.userRoot).TrimEnd('\') -ne $userRoot) {
        throw "The recorded BeamNG user folder has changed: $($state.userRoot)"
    }
    if (-not $SkipRestorePoint) {
        New-FrameGenNGRestorePoint -UserRoot $userRoot -Reason 'before-uninstall' -GameRoot $gameRootResolved -LauncherIni $LauncherIni | Out-Null
    }

    $recoveryRoot = Join-Path (Get-FrameGenNGDataRoot -UserRoot $userRoot) ("recovery-before-uninstall-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $reverseTargets = @($state.targets)
    [array]::Reverse($reverseTargets)
    foreach ($target in $reverseTargets) {
        Restore-TrackedTarget -Target $target -BackupRoot ([string]$state.backupRoot) -AllowedRoots @($gameRootResolved, $userRoot) -RecoveryRoot $recoveryRoot -GameRoot $gameRootResolved
    }

    $settingsPath = [string]$state.settingsPath
    if (-not (Test-PathUnderRoot -Path $settingsPath -Roots @($userRoot))) {
        throw "Settings file is outside the allowed BeamNG user folder: $settingsPath"
    }
    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        foreach ($entry in @($state.settings)) { Restore-SettingState -Settings $settings -State $entry }
        Write-JsonFile -Value $settings -Path $settingsPath -Depth 100
    }
    Clear-BeamNGShaderCache -UserRoot $userRoot

    $archiveState = Join-Path (Split-Path -Parent $statePath) ("uninstalled-state-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    Copy-Item -LiteralPath ([string]$stateRecord.path) -Destination $archiveState -Force
    if (Test-Path -LiteralPath $statePath -PathType Leaf) { Remove-Item -LiteralPath $statePath -Force }
    $redundantStatePath = Join-Path ([string]$state.backupRoot) 'installation-state.json'
    if (Test-Path -LiteralPath $redundantStatePath -PathType Leaf) { Remove-Item -LiteralPath $redundantStatePath -Force }
    Invoke-FrameGenNGTechnicalBackupRetention -UserRoot $userRoot
    return [pscustomobject][ordered]@{
        restored = $true
        profile = [string]$state.profile
        backupKept = [string]$state.backupRoot
        recoveryCreated = if (Test-Path -LiteralPath $recoveryRoot) { $recoveryRoot } else { $null }
        archivedState = $archiveState
        stateRecoveredFromBackup = [bool]$stateRecord.recovered
    }
}

function Reinstall-FrameGenNG {
    [CmdletBinding()]
    param([string]$GameRoot, [string]$LauncherIni)

    $gameRootResolved = Resolve-BeamNGGameRoot -GameRoot $GameRoot
    $userRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
    $stateRecord = Read-FrameGenNGState -UserRoot $userRoot -AllowBackup
    if ($null -eq $stateRecord) {
        throw 'FrameGenNG is not installed. Use Install.'
    }
    $state = $stateRecord.state
    $profile = [string]$state.profile
    $settingsPath = [string]$state.settingsPath
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $enabled = if ($settings.PSObject.Properties.Name -contains $script:SettingsEnabledKey) { [bool]$settings.($script:SettingsEnabledKey) } else { $true }
    $multiplier = if ($settings.PSObject.Properties.Name -contains $script:SettingsMultiplierKey) { [int]$settings.($script:SettingsMultiplierKey) } else { 2 }
    New-FrameGenNGRestorePoint -UserRoot $userRoot -Reason 'before-reinstall' -GameRoot $gameRootResolved -LauncherIni $LauncherIni | Out-Null
    Uninstall-FrameGenNG -GameRoot $gameRootResolved -LauncherIni $LauncherIni -SkipRestorePoint | Out-Null
    $installationState = Install-FrameGenNG -GameRoot $gameRootResolved -LauncherIni $LauncherIni -Profile $profile -SkipRestorePoint
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $settings | Add-Member -NotePropertyName $script:SettingsEnabledKey -NotePropertyValue $enabled -Force
    $settings | Add-Member -NotePropertyName $script:SettingsMultiplierKey -NotePropertyValue $multiplier -Force
    Write-JsonFile -Value $settings -Path $settingsPath -Depth 100
    return $installationState
}

function Get-FrameGenNGStatus {
    [CmdletBinding()]
    param([string]$GameRoot, [string]$LauncherIni)

    $gameRootResolved = Resolve-BeamNGGameRoot -GameRoot $GameRoot
    $userRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
    $statePath = Get-FrameGenNGStatePath -UserRoot $userRoot
    $stateRecord = Read-FrameGenNGState -UserRoot $userRoot -AllowBackup
    if ($null -eq $stateRecord) {
        return [pscustomobject][ordered]@{
            installed = $false
            version = Get-FrameGenNGVersion
            gameRoot = $gameRootResolved
            userRoot = $userRoot
            message = 'FrameGenNG is not installed.'
        }
    }

    $state = $stateRecord.state
    $runtimeConfigReference = Join-Path (Get-FrameGenNGPackageRoot) 'payload\Bin64\FrameGenNG.ini'
    $checks = foreach ($target in @($state.targets)) {
        $destination = [string]$target.destination
        $exists = Test-Path -LiteralPath $destination
        $currentHash = if ($exists) { Get-PathSha256 -Path $destination } else { $null }
        $isRuntimeConfig = [System.IO.Path]::GetFileName($destination).Equals(
            'FrameGenNG.ini',
            [System.StringComparison]::OrdinalIgnoreCase
        )
        $hasInstalledFileRecords = $target.PSObject.Properties.Name -contains 'installedFiles' -and
            $null -ne $target.installedFiles
        $matchesInstalled = if (-not $exists) {
            $false
        } elseif ($isRuntimeConfig -and (Test-Path -LiteralPath $runtimeConfigReference -PathType Leaf)) {
            Test-IniSemanticMatch -Path $destination -ReferencePath $runtimeConfigReference
        } elseif ([bool]$target.isDirectory -and $hasInstalledFileRecords) {
            Test-InstalledDirectoryFiles -Path $destination -InstalledFiles $target.installedFiles
        } else {
            $currentHash -eq [string]$target.installedSha256
        }
        [pscustomobject][ordered]@{
            destination = $destination
            exists = $exists
            matchesInstalled = $matchesInstalled
            currentSha256 = $currentHash
            installedSha256 = [string]$target.installedSha256
        }
    }
    $healthy = @($checks | Where-Object { -not $_.matchesInstalled }).Count -eq 0
    return [pscustomobject][ordered]@{
        installed = $true
        healthy = $healthy
        version = [string]$state.version
        profile = [string]$state.profile
        gpu = [string]$state.gpu
        gameRoot = $gameRootResolved
        userRoot = $userRoot
        checks = @($checks)
        statePath = $statePath
        stateRecoveredFromBackup = [bool]$stateRecord.recovered
        actionRequired = if ([bool]$stateRecord.recovered) { 'Reinstall FrameGenNG to recreate the primary installation state.' } else { $null }
    }
}

Export-ModuleMember -Function @(
    'Install-FrameGenNG',
    'Uninstall-FrameGenNG',
    'Reinstall-FrameGenNG',
    'Get-FrameGenNGStatus',
    'Resolve-BeamNGGameRoot',
    'Resolve-BeamNGUserRoot',
    'Get-NvidiaRtxProfile',
    'Get-FrameGenNGVersion',
    'Get-FrameGenNGRestorePoints',
    'New-FrameGenNGRestorePoint',
    'Remove-FrameGenNGRestorePoint'
)

