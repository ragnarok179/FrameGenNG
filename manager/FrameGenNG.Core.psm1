Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProductName = 'FrameGenNG'
$script:StateFileName = 'install-state.json'
$script:SettingsEnabledKey = 'BeamNGFrameGenerationEnabled'
$script:SettingsMultiplierKey = 'BeamNGFrameGenerationMultiplier'

function Get-FrameGenNGPackageRoot {
    return [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
}

function Get-FrameGenNGVersion {
    $versionPath = Join-Path (Get-FrameGenNGPackageRoot) 'VERSION'
    if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
        throw "Fichier VERSION introuvable : $versionPath"
    }
    return (Get-Content -LiteralPath $versionPath -Raw).Trim()
}

function Assert-BeamNGClosed {
    if ($null -ne (Get-Process -Name 'BeamNG.drive.x64' -ErrorAction SilentlyContinue)) {
        throw 'BeamNG.drive est en cours d execution. Fermez completement le jeu avant de continuer.'
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
FrameGenNG doit etre place directement dans le dossier racine de BeamNG.drive.
Dossier attendu : <BeamNG.drive>\FrameGenNG
Dossier examine : $candidate
Executable attendu : Bin64\BeamNG.drive.x64.exe
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
        throw "Configuration BeamNG introuvable : $LauncherIni. Lancez au moins une fois le launcher BeamNG."
    }

    $configured = $null
    foreach ($line in Get-Content -LiteralPath $LauncherIni) {
        if ($line -match '^\s*userFolder\s*=\s*(.+?)\s*$') {
            $configured = $Matches[1].Trim().Trim('"')
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($configured)) {
        throw "La cle userFolder est absente de $LauncherIni"
    }

    $base = [Environment]::ExpandEnvironmentVariables($configured)
    if (-not [System.IO.Path]::IsPathRooted($base)) {
        $base = Join-Path (Split-Path -Parent $LauncherIni) $base
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
    throw "Dossier utilisateur BeamNG invalide. Aucun settings.json trouve sous $base ou $currentRoot"
}

function Get-FrameGenNGDataRoot {
    param([Parameter(Mandatory)][string]$UserRoot)
    return Join-Path $UserRoot 'FrameGenNG'
}

function Get-FrameGenNGStatePath {
    param([Parameter(Mandatory)][string]$UserRoot)
    return Join-Path (Get-FrameGenNGDataRoot -UserRoot $UserRoot) $script:StateFileName
}

function Get-NvidiaRtxProfile {
    param([ValidateSet('Auto', 'LegacyRTX', 'NativeRTX')][string]$Profile = 'Auto')

    if ($Profile -ne 'Auto') {
        return [pscustomobject]@{ Profile = $Profile; Gpu = 'Profil force par la ligne de commande' }
    }

    $gpuNames = @()
    try {
        $gpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object { [string]$_.Name })
    } catch {
        throw "Impossible de detecter le GPU. Utilisez -Profile LegacyRTX ou -Profile NativeRTX. Detail : $($_.Exception.Message)"
    }
    $rtx = @($gpuNames | Where-Object { $_ -match '(?i)NVIDIA.*RTX' } | Select-Object -First 1)
    if ($rtx.Count -eq 0) {
        throw "Aucun GPU NVIDIA RTX detecte. GPU trouves : $($gpuNames -join ', ')"
    }
    $name = [string]$rtx[0]
    if ($name -match '(?i)RTX\s*(20|30)\d{2}') {
        return [pscustomobject]@{ Profile = 'LegacyRTX'; Gpu = $name }
    }
    if ($name -match '(?i)RTX\s*(40|50)\d{2}') {
        return [pscustomobject]@{ Profile = 'NativeRTX'; Gpu = $name }
    }
    throw "Generation RTX non reconnue : $name. Cette version refuse de choisir un profil non valide."
}

function Get-FileSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-DirectorySha256 {
    param([Parameter(Mandatory)][string]$Path)

    $root = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $lines = foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force | Sort-Object FullName) {
        $relative = $file.FullName.Substring($root.Length).TrimStart('\').Replace('\', '/').ToLowerInvariant()
        "$relative|$(Get-FileSha256 -Path $file.FullName)"
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
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
        throw "Fichier du package manquant : $Source"
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
        [string]$RecoveryRoot
    )
    $destination = [System.IO.Path]::GetFullPath([string]$Target.destination)
    if (-not (Test-PathUnderRoot -Path $destination -Roots $AllowedRoots)) {
        throw "Cible de restauration hors des dossiers autorises : $destination"
    }

    if (Test-Path -LiteralPath $destination) {
        $currentHash = Get-PathSha256 -Path $destination
        $installedHash = [string]$Target.installedSha256
        if (-not [string]::IsNullOrWhiteSpace($RecoveryRoot) -and
            -not [string]::IsNullOrWhiteSpace($installedHash) -and $currentHash -ne $installedHash) {
            New-Item -ItemType Directory -Path $RecoveryRoot -Force | Out-Null
            Copy-Item -LiteralPath $destination -Destination (Join-Path $RecoveryRoot ([string]$Target.backupName)) -Recurse -Force
        }
        Remove-Item -LiteralPath $destination -Recurse -Force
    }

    if ([bool]$Target.existed) {
        $source = Join-Path $BackupRoot ([string]$Target.backupName)
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Sauvegarde d'origine manquante : $source"
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
}

function Get-GraphicsLayoutPatch {
    param([Parameter(Mandatory)][string]$SourcePath)
    $layout = Get-Content -LiteralPath $SourcePath -Raw | ConvertFrom-Json
    $graphics = @($layout.items | Where-Object {
        $_.PSObject.Properties.Name -contains 'categoryId' -and $_.categoryId -eq 'graphics'
    })
    if ($graphics.Count -ne 1) { throw "Categorie graphique BeamNG introuvable ou ambigue : $($graphics.Count)" }

    $groups = @($graphics[0].items | Where-Object {
        $_.PSObject.Properties.Name -contains 'items' -and
        @($_.items | Where-Object { $_.PSObject.Properties.Name -contains 'setting' -and $_.setting -eq 'GraphicAntialiasType' }).Count -eq 1
    })
    if ($groups.Count -ne 1) { throw "Groupe DLSS BeamNG introuvable ou ambigu : $($groups.Count)" }

    $alreadyPatched = @($groups[0].items | Where-Object {
        $_.PSObject.Properties.Name -contains 'setting' -and $_.setting -eq $script:SettingsEnabledKey
    }).Count -gt 0
    if ($alreadyPatched) { return $layout }

    $fgItems = @(
        [pscustomobject][ordered]@{
            version = '0.40'; label = "Génération d’images"; interactive = $false
            condition_always_off = $false; condition_not_shipping = $false; condition_simplemenu = ''
            condition_visible = 'GraphicDLSSSelected'; condition_enabled = ''; itemType = 'heading'
            component = 'OptionsHeading'; icon = '_empty'; variant = 'h4'; search = @('label')
        },
        [pscustomobject][ordered]@{
            version = '0.40'; label = "Activer la génération d’images"
            tooltip = 'Insère des images supplémentaires entre les images rendues par le jeu.'
            setting = $script:SettingsEnabledKey; interactive = $true; condition_always_off = $false
            condition_not_shipping = $false; condition_simplemenu = ''; condition_visible = 'GraphicDLSSSelected'
            condition_enabled = ''; itemType = 'checkbox'; component = 'OptionsCheckbox'; separateLabel = $true
            manualApply = $false; manualLua = ''; lua = ''; luaOff = ''; valueOn = $true; valueOff = $false
            search = @('label', 'caption', 'tooltip', 'setting')
        },
        [pscustomobject][ordered]@{
            version = '0.40'; label = 'Multiplicateur'
            tooltip = '2× est recommandé pour le meilleur équilibre entre fluidité et stabilité.'
            setting = $script:SettingsMultiplierKey; interactive = $true; condition_always_off = $false
            condition_not_shipping = $false; condition_simplemenu = ''; condition_visible = 'GraphicDLSSSelected'
            condition_enabled = $script:SettingsEnabledKey; itemType = 'options'; component = 'BngSmartSelect'
            separateLabel = $true; manualApply = $false; manualLua = ''; optionsSource = ''
            options = @(
                [pscustomobject][ordered]@{ value = 2; label = '2× — Recommandé' },
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
    if (-not $inserted) { throw 'Point d insertion des controles FrameGenNG introuvable apres les reglages DLSS.' }
    $groups[0].items = $newItems.ToArray()
    return $layout
}

function Get-ConditionsPatch {
    param([Parameter(Mandatory)][string]$SourcePath)
    $conditions = Get-Content -LiteralPath $SourcePath -Raw
    if ($conditions -match '\bGraphicDLSSSelected\s*\(') { return $conditions }
    $anchor = '(?ms)(    GraphicAntialiasEnabled\(values\) \{\r?\n      return values\.GraphicAntialiasType !== "off"\r?\n    \},)'
    if ($conditions -notmatch $anchor) { throw 'Point d insertion de la condition DLSS introuvable.' }
    $addition = @'
$1
    GraphicDLSSSelected(values) {
      return values.GraphicAntialiasType === "dlss"
    },
'@
    return [regex]::Replace($conditions, $anchor, $addition, 1)
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

function Install-FrameGenNG {
    [CmdletBinding()]
    param(
        [string]$GameRoot,
        [string]$LauncherIni,
        [ValidateSet('Auto', 'LegacyRTX', 'NativeRTX')][string]$Profile = 'Auto'
    )

    Assert-BeamNGClosed
    $packageRoot = Get-FrameGenNGPackageRoot
    $gameRootResolved = Resolve-BeamNGGameRoot -GameRoot $GameRoot
    $userRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
    $statePath = Get-FrameGenNGStatePath -UserRoot $userRoot
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        throw 'FrameGenNG est deja installe. Utilisez Reparer ou Desinstaller.'
    }

    $gpu = Get-NvidiaRtxProfile -Profile $Profile
    $payloadBin = Join-Path $packageRoot 'payload\Bin64'
    $gameBin = Join-Path $gameRootResolved 'Bin64'
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dataRoot = Get-FrameGenNGDataRoot -UserRoot $userRoot
    $backupRoot = Join-Path $dataRoot "backups\$timestamp"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    $nativeItems = @(
        [pscustomobject]@{ Source = Join-Path $payloadBin 'dxgi.dll'; Destination = Join-Path $gameBin 'dxgi.dll' },
        [pscustomobject]@{ Source = Join-Path $payloadBin 'OptiScaler.ini'; Destination = Join-Path $gameBin 'OptiScaler.ini' },
        [pscustomobject]@{ Source = Join-Path $payloadBin 'OptiScaler'; Destination = Join-Path $gameBin 'OptiScaler' }
    )
    if ($gpu.Profile -eq 'LegacyRTX') {
        $nativeItems += @(
            [pscustomobject]@{ Source = Join-Path $payloadBin 'd3d12.dll'; Destination = Join-Path $gameBin 'd3d12.dll' },
            [pscustomobject]@{ Source = Join-Path $payloadBin 'dlssg_sm86.ini'; Destination = Join-Path $gameBin 'dlssg_sm86.ini' },
            [pscustomobject]@{ Source = Join-Path $payloadBin 'dlssg_sm86'; Destination = Join-Path $gameBin 'dlssg_sm86' }
        )
    }

    $layoutSource = Join-Path $gameRootResolved 'ui\ui-vue\src\modules\options\runtime\layout.json'
    $conditionsSource = Join-Path $gameRootResolved 'ui\ui-vue\src\modules\options\runtime\conditions.js'
    $layoutTarget = Join-Path $userRoot 'ui\ui-vue\src\modules\options\runtime\layout.json'
    $conditionsTarget = Join-Path $userRoot 'ui\ui-vue\src\modules\options\runtime\conditions.js'
    $settingsPath = Join-Path $userRoot 'settings\settings.json'
    $lifecycleRoot = Join-Path $userRoot 'mods\unpacked\FrameGenNG'
    $lifecycleTargets = @(
        [pscustomobject]@{
            Source = Join-Path $packageRoot 'payload\user-mod\scripts\frameGenNG\modScript.lua'
            Destination = Join-Path $lifecycleRoot 'scripts\frameGenNG\modScript.lua'
        },
        [pscustomobject]@{
            Source = Join-Path $packageRoot 'payload\user-mod\lua\ge\extensions\frameGenNGLifecycle.lua'
            Destination = Join-Path $lifecycleRoot 'lua\ge\extensions\frameGenNGLifecycle.lua'
        }
    )

    foreach ($required in @($layoutSource, $conditionsSource, $settingsPath) + @($nativeItems.Source) + @($lifecycleTargets.Source)) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Fichier requis introuvable : $required" }
    }

    $targets = [System.Collections.Generic.List[object]]::new()
    $settingsState = $null
    try {
        $index = 0
        foreach ($item in $nativeItems) {
            $targets.Add((Copy-TargetWithBackup -Source $item.Source -Destination $item.Destination -BackupRoot $backupRoot -Index $index))
            $index++
        }

        $layoutRecord = Backup-WritableTarget -Destination $layoutTarget -BackupRoot $backupRoot -Index $index
        $targets.Add($layoutRecord); $index++
        $patchedLayout = Get-GraphicsLayoutPatch -SourcePath $layoutSource
        Write-JsonFile -Value $patchedLayout -Path $layoutTarget -Depth 100
        $layoutRecord.installedSha256 = Get-PathSha256 -Path $layoutTarget

        $conditionsRecord = Backup-WritableTarget -Destination $conditionsTarget -BackupRoot $backupRoot -Index $index
        $targets.Add($conditionsRecord); $index++
        New-Item -ItemType Directory -Path (Split-Path -Parent $conditionsTarget) -Force | Out-Null
        [System.IO.File]::WriteAllText($conditionsTarget, (Get-ConditionsPatch -SourcePath $conditionsSource), [System.Text.UTF8Encoding]::new($false))
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

        $state = [pscustomobject][ordered]@{
            schemaVersion = 1
            product = $script:ProductName
            version = Get-FrameGenNGVersion
            installedAt = (Get-Date).ToString('o')
            gameRoot = $gameRootResolved
            userRoot = $userRoot
            gpu = [string]$gpu.Gpu
            profile = [string]$gpu.Profile
            backupRoot = $backupRoot
            targets = $targets.ToArray()
            settingsPath = $settingsPath
            settings = $settingsState
        }
        Write-JsonFile -Value $state -Path $statePath -Depth 30
        return $state
    } catch {
        $installError = $_.Exception.Message
        $rollbackError = $null
        try {
            $reverseTargets = @($targets.ToArray())
            [array]::Reverse($reverseTargets)
            foreach ($target in $reverseTargets) {
                Restore-TrackedTarget -Target $target -BackupRoot $backupRoot -AllowedRoots @($gameRootResolved, $userRoot)
            }
            if ($null -ne $settingsState -and (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
                $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
                foreach ($entry in $settingsState) { Restore-SettingState -Settings $settings -State $entry }
                Write-JsonFile -Value $settings -Path $settingsPath -Depth 100
            }
        } catch { $rollbackError = $_.Exception.Message }
        if ($null -ne $rollbackError) {
            throw "Installation interrompue : $installError. La restauration a aussi rencontre une erreur : $rollbackError"
        }
        throw $installError
    }
}

function Uninstall-FrameGenNG {
    [CmdletBinding()]
    param([string]$GameRoot, [string]$LauncherIni)

    Assert-BeamNGClosed
    $gameRootResolved = Resolve-BeamNGGameRoot -GameRoot $GameRoot
    $userRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
    $statePath = Get-FrameGenNGStatePath -UserRoot $userRoot
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        throw 'Aucune installation FrameGenNG enregistree.'
    }
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ([string]$state.product -ne $script:ProductName) { throw 'Le fichier d etat ne correspond pas a FrameGenNG.' }
    if ([System.IO.Path]::GetFullPath([string]$state.gameRoot).TrimEnd('\') -ne $gameRootResolved) {
        throw "L installation enregistree appartient a un autre dossier BeamNG : $($state.gameRoot)"
    }
    if ([System.IO.Path]::GetFullPath([string]$state.userRoot).TrimEnd('\') -ne $userRoot) {
        throw "Le dossier utilisateur enregistre a change : $($state.userRoot)"
    }

    $recoveryRoot = Join-Path (Get-FrameGenNGDataRoot -UserRoot $userRoot) ("recovery-before-uninstall-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $reverseTargets = @($state.targets)
    [array]::Reverse($reverseTargets)
    foreach ($target in $reverseTargets) {
        Restore-TrackedTarget -Target $target -BackupRoot ([string]$state.backupRoot) -AllowedRoots @($gameRootResolved, $userRoot) -RecoveryRoot $recoveryRoot
    }

    $settingsPath = [string]$state.settingsPath
    if (-not (Test-PathUnderRoot -Path $settingsPath -Roots @($userRoot))) {
        throw "Fichier de reglages hors du dossier utilisateur autorise : $settingsPath"
    }
    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        foreach ($entry in @($state.settings)) { Restore-SettingState -Settings $settings -State $entry }
        Write-JsonFile -Value $settings -Path $settingsPath -Depth 100
    }

    $archiveState = Join-Path (Split-Path -Parent $statePath) ("uninstalled-state-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    Copy-Item -LiteralPath $statePath -Destination $archiveState -Force
    Remove-Item -LiteralPath $statePath -Force
    return [pscustomobject][ordered]@{
        restored = $true
        profile = [string]$state.profile
        backupKept = [string]$state.backupRoot
        recoveryCreated = if (Test-Path -LiteralPath $recoveryRoot) { $recoveryRoot } else { $null }
        archivedState = $archiveState
    }
}

function Repair-FrameGenNG {
    [CmdletBinding()]
    param([string]$GameRoot, [string]$LauncherIni)

    $gameRootResolved = Resolve-BeamNGGameRoot -GameRoot $GameRoot
    $userRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
    $statePath = Get-FrameGenNGStatePath -UserRoot $userRoot
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        throw 'FrameGenNG n est pas installe. Utilisez Installer.'
    }
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $profile = [string]$state.profile
    Uninstall-FrameGenNG -GameRoot $gameRootResolved -LauncherIni $LauncherIni | Out-Null
    return Install-FrameGenNG -GameRoot $gameRootResolved -LauncherIni $LauncherIni -Profile $profile
}

function Get-FrameGenNGStatus {
    [CmdletBinding()]
    param([string]$GameRoot, [string]$LauncherIni)

    $gameRootResolved = Resolve-BeamNGGameRoot -GameRoot $GameRoot
    $userRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
    $statePath = Get-FrameGenNGStatePath -UserRoot $userRoot
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        return [pscustomobject][ordered]@{
            installed = $false
            version = Get-FrameGenNGVersion
            gameRoot = $gameRootResolved
            userRoot = $userRoot
            message = 'FrameGenNG n est pas installe.'
        }
    }

    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $checks = foreach ($target in @($state.targets)) {
        $destination = [string]$target.destination
        $exists = Test-Path -LiteralPath $destination
        $currentHash = if ($exists) { Get-PathSha256 -Path $destination } else { $null }
        [pscustomobject][ordered]@{
            destination = $destination
            exists = $exists
            matchesInstalled = $exists -and $currentHash -eq [string]$target.installedSha256
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
    }
}

Export-ModuleMember -Function @(
    'Install-FrameGenNG',
    'Uninstall-FrameGenNG',
    'Repair-FrameGenNG',
    'Get-FrameGenNGStatus',
    'Resolve-BeamNGGameRoot',
    'Resolve-BeamNGUserRoot',
    'Get-NvidiaRtxProfile',
    'Get-FrameGenNGVersion'
)

