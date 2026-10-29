param(
    [string]$GodotPath = (Join-Path $PSScriptRoot 'Runtime\Godot.exe')
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Informe -GodotPath com o executavel Godot 3.6.3. Godot 4 nao e compativel.'
}
$version = (& $GodotPath --version | Out-String).Trim()
if ($version -notmatch '^3\.6\.3\.') {
    throw "Versao incorreta: $version. Use Godot 3.6.3."
}
$pack = Join-Path $PSScriptRoot 'DungeonKeeperStudio.pck'
$stdout = [System.IO.Path]::GetTempFileName()
$stderr = [System.IO.Path]::GetTempFileName()
try {
    $exportArgs = "--no-window --path `"$PSScriptRoot`" --export-pack `"Windows Desktop`" `"$pack`""
    $process = Start-Process -FilePath $GodotPath -ArgumentList $exportArgs -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $pack -PathType Leaf)) {
        Get-Content -LiteralPath $stdout, $stderr | Select-Object -Last 30 | Write-Output
        throw 'A exportacao falhou. Abra project.godot no Godot 3.6.3 para importar os recursos.'
    }
}
finally {
    Remove-Item -LiteralPath $stdout, $stderr -ErrorAction SilentlyContinue
}
Copy-Item -LiteralPath $GodotPath -Destination (Join-Path $PSScriptRoot 'DungeonKeeperStudio.exe') -Force
Write-Output 'DungeonKeeperStudio.exe e DungeonKeeperStudio.pck prontos.'
