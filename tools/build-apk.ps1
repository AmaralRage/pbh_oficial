param(
    [ValidateSet('Debug', 'Release')][string]$Mode = 'Debug',
    [ValidateRange(1, 2100000000)][int]$BuildNumber
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
Push-Location $projectDirectory
try {
    $versionMatch = [regex]::Match((Get-Content pubspec.yaml -Raw), '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)')
    if (-not $versionMatch.Success) { throw 'Confira a versao no pubspec.yaml.' }
    $appVersion = $versionMatch.Groups[1].Value
    if (-not $BuildNumber) { $BuildNumber = [int]$versionMatch.Groups[2].Value }
    if ($Mode -eq 'Release' -and -not (Test-Path android/key.properties)) {
        throw 'A assinatura de distribuicao precisa estar configurada em android/key.properties.'
    }
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    $flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { 'C:/src/flutter/bin/flutter.bat' }
    if (-not (Test-Path -LiteralPath $flutterPath)) { throw 'Flutter nao encontrado.' }
    $modeFlag = '--' + $Mode.ToLowerInvariant()
    & $flutterPath build apk $modeFlag "--build-name=$appVersion" "--build-number=$BuildNumber"
    if ($LASTEXITCODE -ne 0) { throw 'A compilacao falhou. Nenhum APK foi publicado.' }
    New-Item -ItemType Directory -Path build/releases -Force | Out-Null
    $suffix = if ($Mode -eq 'Debug') { '-teste' } else { '' }
    $outputName = "PBH-Oficial-v$appVersion-build$BuildNumber$suffix.apk"
    $sourceApk = "build/app/outputs/flutter-apk/app-$($Mode.ToLowerInvariant()).apk"
    $outputApk = Join-Path 'build/releases' $outputName
    Copy-Item -LiteralPath $sourceApk -Destination $outputApk -Force
    $hash = (Get-FileHash -LiteralPath $outputApk -Algorithm SHA256).Hash
    [System.IO.File]::WriteAllText((Join-Path $projectDirectory "$outputApk.sha256"), "$hash  $outputName`n")
    Write-Output "APK pronto: $outputApk"
    Write-Output "SHA-256: $hash"
} finally { Pop-Location }
