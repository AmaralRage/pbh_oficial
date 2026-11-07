param(
    [ValidateSet('Debug', 'Release')][string]$Mode = 'Debug',
    [ValidateRange(1, 2100000000)][int]$BuildNumber,
    [string]$PreviousApk
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
    if ($Mode -eq 'Release' -and -not $PreviousApk) {
        throw 'Informe -PreviousApk para verificar assinatura e compatibilidade com a instalacao existente.'
    }
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    $flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { 'C:/src/flutter/bin/flutter.bat' }
    if (-not (Test-Path -LiteralPath $flutterPath)) { throw 'Flutter nao encontrado.' }
    $modeFlag = '--' + $Mode.ToLowerInvariant()
    # PowerShell 5 treats Java warnings on stderr as errors. Use the actual
    # Flutter exit code, while preserving the diagnostic output.
    $buildPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $flutterPath build apk $modeFlag "--build-name=$appVersion" "--build-number=$BuildNumber"
        $buildExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $buildPreference }
    if ($buildExit -ne 0) { throw 'A compilacao falhou. Nenhum APK foi publicado.' }
    $sourceApk = "build/app/outputs/flutter-apk/app-$($Mode.ToLowerInvariant()).apk"
    if ($PreviousApk) {
        & (Join-Path $PSScriptRoot 'check-apk-update.ps1') -PreviousApk $PreviousApk -CandidateApk $sourceApk
    }
    New-Item -ItemType Directory -Path build/releases -Force | Out-Null
    $suffix = if ($Mode -eq 'Debug') { '-teste' } else { '' }
    $outputName = "PBH-Oficial-v$appVersion-build$BuildNumber$suffix.apk"
    $outputApk = Join-Path 'build/releases' $outputName
    Copy-Item -LiteralPath $sourceApk -Destination $outputApk -Force
    $hash = (Get-FileHash -LiteralPath $outputApk -Algorithm SHA256).Hash
    [System.IO.File]::WriteAllText((Join-Path $projectDirectory "$outputApk.sha256"), "$hash  $outputName`n")
    Write-Output "APK pronto: $outputApk"
    Write-Output "SHA-256: $hash"
} finally { Pop-Location }
