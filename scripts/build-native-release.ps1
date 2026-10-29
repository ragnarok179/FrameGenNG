[CmdletBinding()]
param(
    [switch]$RefreshSource
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:RendererRoot = Join-Path $script:RepoRoot 'source\renderer'
$script:CacheRoot = Join-Path $script:RepoRoot '.build-cache\native'
$script:SourceRoot = Join-Path $script:CacheRoot 'upstream'
$script:EngineRoot = Join-Path $script:SourceRoot 'FrameGenNGEngine'
$script:PayloadDll = Join-Path $script:RepoRoot 'payload\Bin64\dxgi.dll'
$script:ManifestPath = Join-Path $script:RepoRoot 'payload\manifest.json'
$script:PatchPath = Join-Path $script:RendererRoot 'framegenng-renderer.patch'
$script:ResourceTemplatePath = Join-Path $script:RendererRoot 'FrameGenNG.rc'

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)] [string]$FilePath,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [string]$WorkingDirectory = $script:RepoRoot
    )

    Push-Location -LiteralPath $WorkingDirectory
    try {
        & $FilePath @Arguments | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
        }
    } finally {
        Pop-Location
    }
}

function Assert-ChildPath {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Root
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the build cache: $resolvedPath"
    }
}

function Remove-CachedDirectory {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }
    Assert-ChildPath -Path $Path -Root $script:CacheRoot
    Remove-Item -LiteralPath $Path -Recurse -Force
}

function Get-UpstreamMetadata {
    $readmePath = Join-Path $script:RendererRoot 'README.md'
    $readme = Get-Content -LiteralPath $readmePath -Raw

    $commitMatch = [regex]::Match($readme, '(?m)^([0-9a-f]{40})\r?$')
    $repositoryMatch = [regex]::Match($readme, 'https://github\.com/[^/\s`]+/[^\s`]+')
    if (-not $commitMatch.Success -or -not $repositoryMatch.Success) {
        throw "Unable to read the pinned renderer source from $readmePath"
    }

    $repository = $repositoryMatch.Value.TrimEnd('/', ')', '.', ',')
    if (-not $repository.EndsWith('.git', [System.StringComparison]::OrdinalIgnoreCase)) {
        $repository += '.git'
    }

    [pscustomobject]@{
        Repository = $repository
        Commit = $commitMatch.Groups[1].Value
    }
}

function Get-GitPath {
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($null -eq $git) { throw 'Git for Windows is required to build the native renderer.' }
    $git.Source
}

function Get-MSBuildPath {
    $msBuild = Get-Command MSBuild.exe -ErrorAction SilentlyContinue
    if ($null -ne $msBuild) { return $msBuild.Source }

    $vsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vsWhere -PathType Leaf)) {
        throw 'Visual Studio 2022 or Build Tools 2022 with the C++ workload is required.'
    }

    $matches = @(& $vsWhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe')
    if ($LASTEXITCODE -ne 0 -or $matches.Count -eq 0) {
        throw 'MSBuild was not found. Install Visual Studio 2022 or Build Tools 2022 with the C++ workload.'
    }

    $matches[0]
}

function Test-GitCommitExists {
    param(
        [Parameter(Mandatory)] [string]$GitPath,
        [Parameter(Mandatory)] [string]$RepositoryRoot,
        [Parameter(Mandatory)] [string]$Commit
    )

    & $GitPath -C $RepositoryRoot cat-file -e "$Commit`^{commit}" 2>$null
    $LASTEXITCODE -eq 0
}

function Initialize-UpstreamCache {
    param(
        [Parameter(Mandatory)] [string]$GitPath,
        [Parameter(Mandatory)] [pscustomobject]$Metadata
    )

    New-Item -ItemType Directory -Path $script:CacheRoot -Force | Out-Null

    if ($RefreshSource) {
        Remove-CachedDirectory -Path $script:SourceRoot
    } elseif ((Test-Path -LiteralPath $script:SourceRoot) -and
              -not (Test-Path -LiteralPath (Join-Path $script:SourceRoot '.git'))) {
        Remove-CachedDirectory -Path $script:SourceRoot
    }

    if (-not (Test-Path -LiteralPath (Join-Path $script:SourceRoot '.git'))) {
        Write-Host 'Downloading the pinned renderer source and its dependencies...'
        Invoke-NativeCommand -FilePath $GitPath -Arguments @(
            'clone', '--recursive', $Metadata.Repository, $script:SourceRoot
        )
    }

    $origin = (& $GitPath -C $script:SourceRoot remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read the cached renderer origin.' }
    if ($origin.TrimEnd('/') -ne $Metadata.Repository.TrimEnd('/')) {
        throw "The native source cache uses an unexpected origin: $origin"
    }

    if (-not (Test-GitCommitExists -GitPath $GitPath -RepositoryRoot $script:SourceRoot -Commit $Metadata.Commit)) {
        Write-Host 'Downloading the pinned renderer commit...'
        Invoke-NativeCommand -FilePath $GitPath -Arguments @(
            '-C', $script:SourceRoot, 'fetch', '--no-tags', 'origin', $Metadata.Commit
        )
    }

    Write-Host "Preparing renderer commit $($Metadata.Commit.Substring(0, 8))..."
    Remove-CachedDirectory -Path $script:EngineRoot
    Invoke-NativeCommand -FilePath $GitPath -Arguments @(
        '-C', $script:SourceRoot, 'reset', '--hard', $Metadata.Commit
    )
    Invoke-NativeCommand -FilePath $GitPath -Arguments @(
        '-C', $script:SourceRoot, 'clean', '-ffd'
    )
    Invoke-NativeCommand -FilePath $GitPath -Arguments @(
        '-C', $script:SourceRoot, 'submodule', 'sync', '--recursive'
    )
    Invoke-NativeCommand -FilePath $GitPath -Arguments @(
        '-C', $script:SourceRoot, 'submodule', 'update', '--init', '--recursive', '--force'
    )

    Remove-CachedDirectory -Path (Join-Path $script:SourceRoot 'x64')
}

function Get-RendererProject {
    $candidates = @(
        Get-ChildItem -LiteralPath $script:SourceRoot -Directory |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -Filter '*.vcxproj' -File -ErrorAction SilentlyContinue
            }
    )

    if ($candidates.Count -ne 1) {
        throw "Expected one native renderer project, found $($candidates.Count)."
    }

    $candidates[0]
}

function Replace-RequiredText {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Replacement
    )

    $content = [System.IO.File]::ReadAllText($Path)
    $matches = [regex]::Matches($content, $Pattern)
    if ($matches.Count -ne 1) {
        throw "Expected one normalization match in $Path, found $($matches.Count)."
    }

    $updated = [regex]::Replace($content, $Pattern, $Replacement, 1)
    [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
}

function Apply-FrameGenNGNormalization {
    $project = Get-RendererProject
    $originalEngineRoot = $project.Directory.FullName
    $originalProjectName = $project.Name
    $originalFiltersName = "$originalProjectName.filters"
    $resourceFile = Get-ChildItem -LiteralPath $originalEngineRoot -Filter '*.rc' -File

    if (@($resourceFile).Count -ne 1) {
        throw "Expected one renderer resource script, found $(@($resourceFile).Count)."
    }
    if (Test-Path -LiteralPath $script:EngineRoot) {
        throw "The normalized engine folder already exists: $script:EngineRoot"
    }

    Move-Item -LiteralPath $originalEngineRoot -Destination $script:EngineRoot
    Rename-Item -LiteralPath (Join-Path $script:EngineRoot $originalProjectName) -NewName 'FrameGenNGEngine.vcxproj'
    Rename-Item -LiteralPath (Join-Path $script:EngineRoot $originalFiltersName) -NewName 'FrameGenNGEngine.vcxproj.filters'

    $projectPath = Join-Path $script:EngineRoot 'FrameGenNGEngine.vcxproj'
    $filtersPath = Join-Path $script:EngineRoot 'FrameGenNGEngine.vcxproj.filters'
    $originalResourceName = $resourceFile.Name

    Replace-RequiredText -Path (Join-Path $script:EngineRoot 'Config.h') `
        -Pattern 'std::wstring fileName = L"[^"]+\.ini";' `
        -Replacement 'std::wstring fileName = L"FrameGenNG.ini";'
    Replace-RequiredText -Path (Join-Path $script:EngineRoot 'resource.h') `
        -Pattern '#define VER_PRODUCT_NAME "[^"]+" VER_PRODUCT_VERSION_STR' `
        -Replacement '#define VER_PRODUCT_NAME "FrameGenNG v" VER_PRODUCT_VERSION_STR'
    Replace-RequiredText -Path $projectPath `
        -Pattern ([regex]::Escape($originalResourceName)) `
        -Replacement 'FrameGenNG.rc'
    Replace-RequiredText -Path $filtersPath `
        -Pattern ([regex]::Escape($originalResourceName)) `
        -Replacement 'FrameGenNG.rc'

    Remove-Item -LiteralPath (Join-Path $script:EngineRoot $originalResourceName) -Force
    Copy-Item -LiteralPath $script:ResourceTemplatePath `
        -Destination (Join-Path $script:EngineRoot 'FrameGenNG.rc') -Force
}

function Apply-RendererPatch {
    param([Parameter(Mandatory)] [string]$GitPath)

    Write-Host 'Applying the FrameGenNG renderer patch...'
    Invoke-NativeCommand -FilePath $GitPath -Arguments @(
        '-C', $script:SourceRoot, 'apply', '--check', $script:PatchPath
    )
    Invoke-NativeCommand -FilePath $GitPath -Arguments @(
        '-C', $script:SourceRoot, 'apply', $script:PatchPath
    )
}

function Build-NativeRenderer {
    param([Parameter(Mandatory)] [string]$MSBuildPath)

    $projectPath = Join-Path $script:EngineRoot 'FrameGenNGEngine.vcxproj'
    $solutionDirectory = $script:SourceRoot.TrimEnd('\') + '\'

    Write-Host 'Compiling the native renderer (Release x64)...'
    Invoke-NativeCommand -FilePath $MSBuildPath -Arguments @(
        $projectPath,
        '/m',
        '/t:Rebuild',
        '/p:Configuration=Release',
        '/p:Platform=x64',
        "/p:SolutionDir=$solutionDirectory",
        '/v:minimal'
    ) -WorkingDirectory $script:SourceRoot

    $builtDll = Join-Path $script:SourceRoot 'x64\Release\a\FrameGenNGEngine.dll'
    if (-not (Test-Path -LiteralPath $builtDll -PathType Leaf)) {
        throw "The native build completed without producing $builtDll"
    }

    $binary = Get-Item -LiteralPath $builtDll
    if ($binary.Length -lt 1MB) {
        throw "The compiled renderer is unexpectedly small: $($binary.Length) bytes."
    }

    $productName = $binary.VersionInfo.ProductName
    if ($productName -notlike 'FrameGenNG*') {
        throw "The compiled renderer has unexpected product metadata: $productName"
    }

    $builtDll
}

function Publish-TestPackage {
    param([Parameter(Mandatory)] [string]$BuiltDll)

    $transactionRoot = Join-Path $script:CacheRoot 'package-transaction'
    Remove-CachedDirectory -Path $transactionRoot
    New-Item -ItemType Directory -Path $transactionRoot -Force | Out-Null

    $dllBackup = Join-Path $transactionRoot 'dxgi.dll'
    $manifestBackup = Join-Path $transactionRoot 'manifest.json'
    Copy-Item -LiteralPath $script:PayloadDll -Destination $dllBackup -Force
    Copy-Item -LiteralPath $script:ManifestPath -Destination $manifestBackup -Force

    $removeTransaction = $false
    try {
        Copy-Item -LiteralPath $BuiltDll -Destination $script:PayloadDll -Force
        $package = & (Join-Path $PSScriptRoot 'build-release.ps1')
        if ($null -eq $package) { throw 'The package build returned no result.' }
        $removeTransaction = $true
        $package
    } catch {
        $buildError = $_
        try {
            Copy-Item -LiteralPath $dllBackup -Destination $script:PayloadDll -Force
            Copy-Item -LiteralPath $manifestBackup -Destination $script:ManifestPath -Force
            $removeTransaction = $true
        } catch {
            throw "The package build failed and its previous payload could not be restored. Recovery files remain in $transactionRoot. Build error: $buildError Rollback error: $_"
        }
        throw $buildError
    } finally {
        if ($removeTransaction) {
            Remove-CachedDirectory -Path $transactionRoot
        }
    }
}

if (-not (Test-Path -LiteralPath $script:PatchPath -PathType Leaf)) {
    throw "Renderer patch is missing: $script:PatchPath"
}
if (-not (Test-Path -LiteralPath $script:ResourceTemplatePath -PathType Leaf)) {
    throw "Renderer resource template is missing: $script:ResourceTemplatePath"
}

$metadata = Get-UpstreamMetadata
$gitPath = Get-GitPath
$msBuildPath = Get-MSBuildPath

Initialize-UpstreamCache -GitPath $gitPath -Metadata $metadata
Apply-FrameGenNGNormalization
Apply-RendererPatch -GitPath $gitPath
$builtDll = Build-NativeRenderer -MSBuildPath $msBuildPath
$nativeHash = (Get-FileHash -LiteralPath $builtDll -Algorithm SHA256).Hash.ToLowerInvariant()
$package = Publish-TestPackage -BuiltDll $builtDll

Write-Host ''
Write-Host 'FrameGenNG native test package created successfully.' -ForegroundColor Green
Write-Host "Native DLL SHA-256: $nativeHash"
Write-Host "Package: $($package.zip)"
Write-Host "Package SHA-256: $($package.sha256)"

[pscustomobject]@{
    zip = $package.zip
    sha256 = $package.sha256
    size = $package.size
    nativeDllSha256 = $nativeHash
    upstreamCommit = $metadata.Commit
}
