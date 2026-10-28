[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
& (Join-Path $PSScriptRoot 'Update-PayloadManifest.ps1') | Out-Null
$distRoot = Join-Path $repoRoot 'dist'
$stageRoot = Join-Path $distRoot "FrameGenNG-v$version"
$packageRoot = Join-Path $stageRoot 'FrameGenNG'
$zipPath = Join-Path $distRoot "FrameGenNG-v$version.zip"

if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

$releaseEntries = @(
    '.gitignore', 'VERSION', 'README.md', 'LICENSE', 'NOTICE', 'THIRD_PARTY_NOTICES.md',
    'FrameGenNG Manager.cmd', 'Install FrameGenNG.cmd', 'Repair FrameGenNG.cmd', 'Uninstall FrameGenNG.cmd',
    'manager', 'payload', 'docs', 'licenses', 'source'
)
foreach ($entry in $releaseEntries) {
    Copy-Item -LiteralPath (Join-Path $repoRoot $entry) -Destination $packageRoot -Recurse -Force
}

Compress-Archive -LiteralPath $packageRoot -DestinationPath $zipPath -CompressionLevel Optimal
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $invalid = @($zip.Entries | Where-Object {
        $normalizedName = $_.FullName.Replace('\', '/')
        -not $normalizedName.StartsWith('FrameGenNG/', [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($invalid.Count -gt 0) { throw 'The ZIP contains files outside the FrameGenNG folder.' }
} finally {
    $zip.Dispose()
}

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText("$zipPath.sha256", "$hash  $(Split-Path -Leaf $zipPath)`n", [System.Text.UTF8Encoding]::new($false))
[pscustomobject]@{ zip = $zipPath; sha256 = $hash; size = (Get-Item -LiteralPath $zipPath).Length }

