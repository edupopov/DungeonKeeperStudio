#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$SomenteGodot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'Este kit contem aplicativos Windows x64. Use um Windows de 64 bits.'
}
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Get-VerifiedDownload {
    param([string]$Url, [string]$Path, [string]$Sha256)
    if (Test-Path -LiteralPath $Path) {
        if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Sha256) {
            throw "Arquivo existente com hash diferente: $Path. Foi preservado; mova-o antes de tentar novamente."
        }
        Write-Output "Verificado: $Path"
        return
    }
    $pending = "$Path.download"
    if (Test-Path -LiteralPath $pending) {
        throw "Download incompleto existente: $pending. Foi preservado; mova-o antes de tentar novamente."
    }
    Invoke-WebRequest -Uri $Url -OutFile $pending -UseBasicParsing
    if ((Get-FileHash -LiteralPath $pending -Algorithm SHA256).Hash -ne $Sha256) {
        throw "Checksum incorreto em $pending. O arquivo nao sera executado nem extraido."
    }
    Move-Item -LiteralPath $pending -Destination $Path
    Write-Output "Baixado e verificado: $Path"
}

$apps = Join-Path $PSScriptRoot 'Aplicativos'
New-Item -ItemType Directory -Path $apps -Force | Out-Null
$archive = Join-Path $apps 'Godot_v3.6.3-stable_win64.exe.zip'
Get-VerifiedDownload `
    -Url 'https://github.com/godotengine/godot-builds/releases/download/3.6.3-stable/Godot_v3.6.3-stable_win64.exe.zip' `
    -Path $archive `
    -Sha256 '80616a2621025b508a5ed14a5066630fb6c0c384ecab87277bf33569e965eec3'

$godot = Join-Path $apps 'Godot-3.6.3'
$executable = Join-Path $godot 'Godot_v3.6.3-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godot)) {
    $staging = "$godot.pending"
    if (Test-Path -LiteralPath $staging) {
        throw "Extracao incompleta existente: $staging. Mova-a antes de tentar novamente."
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $staging
    $stagedExe = Join-Path $staging 'Godot_v3.6.3-stable_win64.exe'
    if (-not (Test-Path -LiteralPath $stagedExe -PathType Leaf) -or
        (Get-FileHash -LiteralPath $stagedExe -Algorithm SHA256).Hash -ne '958aac5115c00a7e2fe560c1296d5d49d51c62e80b36f660d2b4ebb46a153179') {
        throw "Executavel Godot inesperado em $staging. Nada foi instalado."
    }
    Move-Item -LiteralPath $staging -Destination $godot
}
if (-not (Test-Path -LiteralPath $executable -PathType Leaf) -or
    (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -ne '958aac5115c00a7e2fe560c1296d5d49d51c62e80b36f660d2b4ebb46a153179') {
    throw "Godot existente ausente ou alterado: $executable. Foi preservado."
}
$root = Split-Path -Parent $PSScriptRoot
foreach ($license in @('GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt')) {
    Copy-Item -LiteralPath (Join-Path $root $license) -Destination (Join-Path $godot $license) -Force
}
Write-Output "Godot portatil pronto: $executable"

if (-not $SomenteGodot) {
    Get-VerifiedDownload `
        -Url 'https://github.com/ip7z/7zip/releases/download/26.05/7z2605-x64.exe' `
        -Path (Join-Path $apps '7z2605-x64.exe') `
        -Sha256 'fd99e86f57d8f429ef5ed045bf98315af962e2309b0f1ba87a147a44c71647d0'
    Get-VerifiedDownload `
        -Url 'https://keeperfx.net/download/web-installer/0c014ed3/keeperfx-web-installer.exe' `
        -Path (Join-Path $apps 'keeperfx-web-installer-0c014ed3.exe') `
        -Sha256 '4d67259f14d2d9693a6342252c5cd9a546fd019be2d3f8b4907e67a3cbacc5a9'
}
Write-Output 'Kit pronto. Nenhum instalador foi executado; o jogo e suas configuracoes nao foram alterados.'
