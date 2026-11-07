param(
    [Parameter(Mandatory = $true)][string]$PreviousApk,
    [Parameter(Mandatory = $true)][string]$CandidateApk,
    [string]$SdkDirectory = "$env:LOCALAPPDATA/Android/Sdk"
)
$ErrorActionPreference = 'Stop'
$previousJava = $env:JAVA_HOME
try {
    if (-not $env:JAVA_HOME -and (Test-Path 'C:/Program Files/Android/Android Studio/jbr')) {
        $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
    }
    $buildTools = Get-ChildItem -LiteralPath (Join-Path $SdkDirectory 'build-tools') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if (-not $buildTools) { throw 'Android build-tools nao encontrado.' }
    $signer = Join-Path $buildTools.FullName 'apksigner.bat'
    $aapt = Join-Path $buildTools.FullName 'aapt.exe'
    function Read-ApkIdentity([string]$apk) {
        $resolved = (Resolve-Path -LiteralPath $apk).Path
        $savedPreference = $ErrorActionPreference
        try {
            # Windows PowerShell turns Java stderr warnings into ErrorRecords.
            # Preserve them privately and use the actual tool exit status.
            $ErrorActionPreference = 'Continue'
            $signature = & $signer verify --print-certs $resolved 2>&1
            $signatureExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $savedPreference }
        if ($signatureExit -ne 0) { throw 'Assinatura do APK invalida ou impossivel de verificar.' }
        $digests = @([regex]::Matches(($signature -join "`n"), 'Signer #\d+ certificate SHA-256 digest:\s*([a-fA-F0-9]{64})') |
            ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } | Sort-Object -Unique)
        if (-not $digests.Count) { throw 'Certificado do APK nao encontrado.' }
        try {
            $ErrorActionPreference = 'Continue'
            $badging = & $aapt dump badging $resolved 2>&1
            $badgingExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $savedPreference }
        if ($badgingExit -ne 0) { throw 'Nao foi possivel ler a versao do APK.' }
        $package = [regex]::Match(($badging -join "`n"), "package: name='([^']+)' versionCode='(\d+)'")
        if (-not $package.Success) { throw 'Identidade do pacote ausente.' }
        return @{ Package = $package.Groups[1].Value; Version = [long]$package.Groups[2].Value; Signers = ($digests -join ',') }
    }
    $previous = Read-ApkIdentity $PreviousApk
    $candidate = Read-ApkIdentity $CandidateApk
    if ($previous.Package -ne $candidate.Package) { throw 'Pacotes diferentes: o candidato nao e uma atualizacao do app.' }
    # Conservatively reject different signers. Signing-key rotation/lineage needs
    # a separate migration plan; never suggest uninstalling to bypass this gate.
    if ($previous.Signers -ne $candidate.Signers) { throw 'Assinaturas diferentes: este APK nao atualiza diretamente a instalacao de referencia.' }
    if ($candidate.Version -le $previous.Version) { throw 'O versionCode do candidato deve ser maior que o do APK anterior.' }
    Write-Output "Compatibilidade confirmada: $($candidate.Package), versionCode $($previous.Version) -> $($candidate.Version), mesmo certificado."
} finally { $env:JAVA_HOME = $previousJava }
