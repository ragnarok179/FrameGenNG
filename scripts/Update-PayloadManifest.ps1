[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$payloadRoot = Join-Path $repoRoot 'payload'
$manifestPath = Join-Path $payloadRoot 'manifest.json'

$files = foreach ($file in Get-ChildItem -LiteralPath $payloadRoot -Recurse -File -Force | Where-Object { $_.FullName -ne $manifestPath } | Sort-Object FullName) {
    [pscustomobject][ordered]@{
        path = $file.FullName.Substring($payloadRoot.Length).TrimStart('\').Replace('\', '/')
        size = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$manifest = [pscustomobject][ordered]@{
    schemaVersion = 1
    packageVersion = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
    profiles = [pscustomobject][ordered]@{
        NativeRTX = @('Bin64/dxgi.dll', 'Bin64/OptiScaler.ini', 'Bin64/OptiScaler/**', 'user-mod/**')
        LegacyRTX = @('NativeRTX', 'Bin64/d3d12.dll', 'Bin64/dlssg_sm86.ini', 'Bin64/dlssg_sm86/**')
    }
    files = @($files)
}
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
$manifestPath

