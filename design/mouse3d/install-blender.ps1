# Installs the pinned Blender 5.2.3 LTS for Windows (portable zip, no admin rights) and verifies
# its SHA-256 against the official value before extracting.
#   powershell -NoProfile -ExecutionPolicy Bypass -File design\mouse3d\install-blender.ps1
# (ASCII only: Windows PowerShell 5.1 reads BOM-less scripts with the ANSI code page.)
param(
    [string]$Destination = ''
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # the progress bar makes Invoke-WebRequest very slow on 5.1

if (-not $Destination) { $Destination = Join-Path $env:LOCALAPPDATA 'Programs' }
$name = 'blender-5.2.3-windows-x64'
$expected = '723f08a4401502561eb763cdeacf8745b31e5f3f154d287d3830d97cf75dc2fb'
$exe = Join-Path (Join-Path $Destination $name) 'blender.exe'

if (Test-Path -LiteralPath $exe) {
    Write-Host "Blender ja instalado: $exe"
    & $exe --version
    exit 0
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$zip = Join-Path ([System.IO.Path]::GetTempPath()) "$name.zip"
Write-Host "Baixando $name.zip (cerca de 370 MB)..."
Invoke-WebRequest -Uri "https://download.blender.org/release/Blender5.2/$name.zip" -OutFile $zip -UseBasicParsing

$actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
if ($actual -ne $expected) {
    Remove-Item -LiteralPath $zip
    throw "SHA-256 diferente do oficial ($actual). Download descartado."
}
Write-Host 'SHA-256 confere. Extraindo...'

$tar = $null
if ($env:SystemRoot) { $tar = Join-Path $env:SystemRoot 'System32\tar.exe' }
if ($tar -and (Test-Path -LiteralPath $tar)) {
    & $tar -xf $zip -C $Destination
    if ($LASTEXITCODE -ne 0) { throw "tar.exe falhou com codigo $LASTEXITCODE" }
} else {
    Expand-Archive -LiteralPath $zip -DestinationPath $Destination -Force
}
Remove-Item -LiteralPath $zip

if (-not (Test-Path -LiteralPath $exe)) { throw "blender.exe nao encontrado em $exe depois de extrair" }
& $exe --version
