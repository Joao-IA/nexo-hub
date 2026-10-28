# Runs build.py with the pinned Blender on Windows (PowerShell 5.1 or 7).
#   powershell -NoProfile -ExecutionPolicy Bypass -File design\mouse3d\run.ps1 <task> [options]
# Blender is looked up in $env:NEXO_BLENDER, then in the default install location of the README.
$ErrorActionPreference = 'Stop'

$blender = $env:NEXO_BLENDER
if (-not $blender) {
    $blender = Join-Path $env:LOCALAPPDATA 'Programs\blender-5.2.3-windows-x64\blender.exe'
}
if (-not (Test-Path -LiteralPath $blender)) {
    Write-Host "Blender 5.2.3 nao encontrado em $blender. Instale conforme design\mouse3d\README.md ou defina NEXO_BLENDER."
    exit 2
}
$script = Join-Path $PSScriptRoot 'build.py'
# '--' is quoted so PowerShell passes it to Blender instead of treating it as its own token.
& $blender -b --factory-startup --python-exit-code 1 --python $script '--' @args
exit $LASTEXITCODE
