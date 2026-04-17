param(
    [ValidateSet('release', 'debug', 'profile')]
    [string]$Mode = 'release',

    [switch]$SplitPerAbi,

    [switch]$SkipPubGet,

    [switch]$NoTreeShakeIcons
)

$ErrorActionPreference = 'Stop'

function Get-PubspecVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PubspecPath
    )

    $versionLine = Select-String -Path $PubspecPath -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if ($null -eq $versionLine) {
        return 'unknown'
    }

    return $versionLine.Matches[0].Groups[1].Value.Trim()
}

function Copy-ApkArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$Mode,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [bool]$SplitPerAbi
    )

    $apkOutputDir = Join-Path $RepoRoot 'build\app\outputs\flutter-apk'
    if (-not (Test-Path $apkOutputDir)) {
        throw "APK output directory not found: $apkOutputDir"
    }

    if ($SplitPerAbi) {
        $apks = Get-ChildItem -Path $apkOutputDir -Filter "*-$Mode.apk" | Sort-Object Name
    } else {
        $apks = Get-ChildItem -Path $apkOutputDir -Filter "app-$Mode.apk"
    }

    if (-not $apks) {
        throw "No APK artifacts were found in $apkOutputDir"
    }

    $artifactDir = Join-Path $RepoRoot 'build\class-apk'
    New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

    $copiedPaths = @()
    foreach ($apk in $apks) {
        $suffix = $apk.BaseName
        if ($suffix.StartsWith('app-')) {
            $suffix = $suffix.Substring(4)
        }

        $versionTag = $Version -replace '[^0-9A-Za-z\.\+\-_]', '_'
        $targetName = "moyun-$versionTag-$suffix.apk"
        $targetPath = Join-Path $artifactDir $targetName
        Copy-Item -Path $apk.FullName -Destination $targetPath -Force
        $copiedPaths += $targetPath

        $latestName = if ($SplitPerAbi) {
            "latest-$suffix.apk"
        } else {
            "latest-$Mode.apk"
        }
        $latestPath = Join-Path $artifactDir $latestName
        Copy-Item -Path $apk.FullName -Destination $latestPath -Force
    }

    return $copiedPaths
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$version = Get-PubspecVersion -PubspecPath $pubspecPath
$keyPropertiesPath = Join-Path $repoRoot 'android\key.properties'

Push-Location $repoRoot
try {
    Write-Host "Repo root: $repoRoot"
    Write-Host "Build mode: $Mode"
    Write-Host "App version: $version"

    if (-not (Test-Path $keyPropertiesPath) -and $Mode -eq 'release') {
        Write-Host "android/key.properties not found. Using the project's current release configuration."
    }

    if (-not $SkipPubGet) {
        Write-Host 'Running flutter pub get...'
        & flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw "flutter pub get failed with exit code $LASTEXITCODE"
        }
    }

    $buildArgs = @('build', 'apk', "--$Mode")
    if ($SplitPerAbi) {
        $buildArgs += '--split-per-abi'
    }
    if ($NoTreeShakeIcons) {
        $buildArgs += '--no-tree-shake-icons'
    }

    Write-Host "Running: flutter $($buildArgs -join ' ')"
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk failed with exit code $LASTEXITCODE"
    }

    $artifactPaths = Copy-ApkArtifacts -RepoRoot $repoRoot -Mode $Mode -Version $version -SplitPerAbi:$SplitPerAbi

    Write-Host ''
    Write-Host 'APK artifacts:'
    foreach ($path in $artifactPaths) {
        $item = Get-Item $path
        $sizeMb = [Math]::Round($item.Length / 1MB, 2)
        Write-Host " - $path ($sizeMb MB)"
    }
}
finally {
    Pop-Location
}
