param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$TemplateDirectory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$previousAppData = $env:APPDATA
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    $env:APPDATA = Join-Path $root '.runtime'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    Set-Content (Join-Path $env:APPDATA '.gdignore') ''
    $env:TEMP = Join-Path $env:APPDATA 'tmp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force $env:TEMP | Out-Null
    $templates = Join-Path $env:APPDATA 'Godot/export_templates/4.7.stable'
    New-Item -ItemType Directory -Force $templates | Out-Null
    Copy-Item (Join-Path $TemplateDirectory 'windows_release_x86_64*.exe') $templates -Force
    New-Item -ItemType Directory -Force (Join-Path $root 'dist') | Out-Null
    Set-Content (Join-Path $root 'dist/.gdignore') ''
    # Export performs the import itself. A separate Windows --editor --import
    # shutdown crashed on the CI runner before the export could be attempted.
    & $Godot --headless --path $root --log-file (Join-Path $env:APPDATA 'godot-export.log') --export-release 'Windows Desktop' (Join-Path $root 'dist/FacilityEscape.exe')
    if ($LASTEXITCODE -ne 0) { throw "Godot export failed: $LASTEXITCODE" }
    Get-FileHash (Join-Path $root 'dist/FacilityEscape.exe') -Algorithm SHA256
} finally { $env:APPDATA = $previousAppData; $env:TEMP = $previousTemp; $env:TMP = $previousTmp }
