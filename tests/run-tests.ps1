[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ECHEC : $Message" }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

Write-Host '1/3 Analyse syntaxique PowerShell'
$parseErrors = [System.Collections.Generic.List[object]]::new()
foreach ($file in Get-ChildItem -LiteralPath $repoRoot -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') }) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    foreach ($error in @($errors)) { $parseErrors.Add([pscustomobject]@{ file = $file.FullName; error = $error.Message }) }
}
Assert-True ($parseErrors.Count -eq 0) (($parseErrors | Format-Table | Out-String).Trim())

Write-Host '2/3 Préparation du jeu factice'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("FrameGenNG-tests-" + [Guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $testRoot 'BeamNG.drive\FrameGenNG'
$gameRoot = Split-Path -Parent $packageRoot
$userBase = Join-Path $testRoot 'UserData'
$userRoot = Join-Path $userBase 'current'
$launcherIni = Join-Path $testRoot 'BeamNG.drive.ini'

try {
    New-Item -ItemType Directory -Path (Join-Path $packageRoot 'manager'),(Join-Path $packageRoot 'payload\Bin64\OptiScaler\streamline'),(Join-Path $packageRoot 'payload\Bin64\dlssg_sm86\runtime'),(Join-Path $packageRoot 'payload\Bin64\dlssg_sm86\backend'),(Join-Path $packageRoot 'payload\Bin64\dlssg_sm86\kernels'),(Join-Path $packageRoot 'payload\user-mod\scripts\frameGenNG'),(Join-Path $packageRoot 'payload\user-mod\lua\ge\extensions'),(Join-Path $gameRoot 'Bin64'),(Join-Path $gameRoot 'ui\ui-vue\src\modules\options\runtime'),(Join-Path $userRoot 'settings') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'manager\FrameGenNG.Core.psm1') -Destination (Join-Path $packageRoot 'manager\FrameGenNG.Core.psm1')
    Write-Utf8NoBom -Path (Join-Path $packageRoot 'VERSION') -Content '0.0.0-test'

    $dummyFiles = @(
        'payload\Bin64\dxgi.dll', 'payload\Bin64\d3d12.dll', 'payload\Bin64\OptiScaler.ini',
        'payload\Bin64\OptiScaler\streamline\sl.common.dll', 'payload\Bin64\dlssg_sm86.ini',
        'payload\Bin64\dlssg_sm86\runtime\nvngx_dlssg.dll',
        'payload\Bin64\dlssg_sm86\backend\sm86_backend.dll',
        'payload\Bin64\dlssg_sm86\kernels\fg_kernels.dll',
        'payload\user-mod\scripts\frameGenNG\modScript.lua',
        'payload\user-mod\lua\ge\extensions\frameGenNGLifecycle.lua'
    )
    foreach ($relative in $dummyFiles) { Write-Utf8NoBom -Path (Join-Path $packageRoot $relative) -Content "PAYLOAD:$relative" }

    Write-Utf8NoBom -Path (Join-Path $gameRoot 'Bin64\BeamNG.drive.x64.exe') -Content 'FAKE-EXE'
    Write-Utf8NoBom -Path (Join-Path $gameRoot 'Bin64\dxgi.dll') -Content 'ORIGINAL-DXGI'
    $layout = '{"items":[{"categoryId":"graphics","items":[{"items":[{"setting":"GraphicAntialiasType"},{"setting":"GraphicUpscalingSharpness"}]}]}]}'
    Write-Utf8NoBom -Path (Join-Path $gameRoot 'ui\ui-vue\src\modules\options\runtime\layout.json') -Content $layout
    $conditions = @'
    GraphicAntialiasEnabled(values) {
      return values.GraphicAntialiasType !== "off"
    },
'@
    Write-Utf8NoBom -Path (Join-Path $gameRoot 'ui\ui-vue\src\modules\options\runtime\conditions.js') -Content $conditions
    Write-Utf8NoBom -Path (Join-Path $userRoot 'settings\settings.json') -Content '{"GraphicAntialiasType":"dlss","OtherSetting":123}'
    Write-Utf8NoBom -Path $launcherIni -Content "userFolder = $userBase`n"

    Import-Module (Join-Path $packageRoot 'manager\FrameGenNG.Core.psm1') -Force

    Write-Host '3/3 Cycle NativeRTX puis LegacyRTX'
    $native = Install-FrameGenNG -GameRoot $gameRoot -LauncherIni $launcherIni -Profile NativeRTX
    Assert-True ($native.profile -eq 'NativeRTX') 'Le profil NativeRTX doit être enregistré.'
    Assert-True (Test-Path -LiteralPath (Join-Path $gameRoot 'Bin64\dxgi.dll')) 'dxgi.dll doit être installé.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $gameRoot 'Bin64\d3d12.dll'))) 'Le profil NativeRTX ne doit pas installer le proxy SM86.'
    $settings = Get-Content -LiteralPath (Join-Path $userRoot 'settings\settings.json') -Raw | ConvertFrom-Json
    Assert-True ([bool]$settings.BeamNGFrameGenerationEnabled) 'Le réglage FG doit être activé.'
    Assert-True ([int]$settings.BeamNGFrameGenerationMultiplier -eq 2) 'Le multiplicateur par défaut doit être 2x.'
    $patchedLayout = Get-Content -LiteralPath (Join-Path $userRoot 'ui\ui-vue\src\modules\options\runtime\layout.json') -Raw
    Assert-True ($patchedLayout -match 'BeamNGFrameGenerationEnabled') 'Les contrôles doivent être présents dans le layout.'

    $settings.OtherSetting = 456
    Write-Utf8NoBom -Path (Join-Path $userRoot 'settings\settings.json') -Content ($settings | ConvertTo-Json -Depth 20)
    Uninstall-FrameGenNG -GameRoot $gameRoot -LauncherIni $launcherIni | Out-Null
    Assert-True ((Get-Content -LiteralPath (Join-Path $gameRoot 'Bin64\dxgi.dll') -Raw) -eq 'ORIGINAL-DXGI') 'dxgi.dll original doit être restauré.'
    $restoredSettings = Get-Content -LiteralPath (Join-Path $userRoot 'settings\settings.json') -Raw | ConvertFrom-Json
    Assert-True ([int]$restoredSettings.OtherSetting -eq 456) 'La désinstallation doit préserver les autres réglages modifiés après installation.'
    Assert-True (-not ($restoredSettings.PSObject.Properties.Name -contains 'BeamNGFrameGenerationEnabled')) 'La clé FG ajoutée doit être retirée.'

    $legacy = Install-FrameGenNG -GameRoot $gameRoot -LauncherIni $launcherIni -Profile LegacyRTX
    Assert-True ($legacy.profile -eq 'LegacyRTX') 'Le profil LegacyRTX doit être enregistré.'
    Assert-True (Test-Path -LiteralPath (Join-Path $gameRoot 'Bin64\d3d12.dll')) 'Le profil LegacyRTX doit installer d3d12.dll.'
    Assert-True (Test-Path -LiteralPath (Join-Path $gameRoot 'Bin64\dlssg_sm86\kernels\fg_kernels.dll')) 'Le pack de kernels SM86 doit être installé.'
    Write-Utf8NoBom -Path (Join-Path $gameRoot 'Bin64\dxgi.dll') -Content 'MODIFIED-AFTER-INSTALL'
    $uninstall = Uninstall-FrameGenNG -GameRoot $gameRoot -LauncherIni $launcherIni
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$uninstall.recoveryCreated)) 'Une copie de récupération doit être créée pour un fichier modifié.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $gameRoot 'Bin64\dxgi.dll') -Raw) -eq 'ORIGINAL-DXGI') 'La seconde désinstallation doit restaurer dxgi.dll.'

    Write-Host 'Tous les tests FrameGenNG ont réussi.' -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = [System.IO.Path]::GetFullPath($testRoot)
        $temp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
        if ($resolved.StartsWith($temp + '\FrameGenNG-tests-', [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

