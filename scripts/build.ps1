param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$TemplateDirectory,
    [switch]$VerifyPlayer
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
    $exportExitCode = $LASTEXITCODE
    $exportLog = Get-Content (Join-Path $env:APPDATA 'godot-export.log') -Raw
    $packComplete = $exportLog -match '\[ DONE \] savepack'
    $executable = Join-Path $root 'dist/FacilityEscape.exe'
    $library = Join-Path $root 'dist/gua_godot.windows.release.x86_64.dll'
    $evidence = Join-Path $root 'artifacts/build'
    New-Item -ItemType Directory -Force $evidence | Out-Null
    Copy-Item (Join-Path $env:APPDATA 'godot-export.log') (Join-Path $evidence 'editor.log') -Force
    if (!(Test-Path $executable) -or !(Test-Path $library)) { throw 'Windows EXE or Gua DLL was not exported' }
    if ($exportExitCode -ne 0 -and !($VerifyPlayer -and $exportExitCode -eq -1073741819 -and $packComplete)) {
        throw "Godot export failed: $exportExitCode"
    }
    $hash = (Get-FileHash $executable -Algorithm SHA256).Hash.ToLowerInvariant()
    $report = @{exportExitCode=$exportExitCode; packComplete=$packComplete; sha256=$hash; playerAcceptancePassed=$false; editorShutdownCrash=($exportExitCode -eq -1073741819)}
    $report | ConvertTo-Json | Set-Content (Join-Path $evidence 'export.json')
    if ($VerifyPlayer) {
        & node (Join-Path $root 'tests/acceptance.mjs') $executable
        if ($LASTEXITCODE -ne 0) { throw 'Exported Windows EXE failed Gua acceptance' }
        $report.playerAcceptancePassed = $true
        $report | ConvertTo-Json | Set-Content (Join-Path $evidence 'export.json')
    }
    if ($exportExitCode -ne 0) { Write-Warning "Godot editor crashed after packing ($exportExitCode); the exported EXE passed Gua acceptance. Editor shutdown remains a known CI limitation; see artifacts/build." }
    Write-Output "Windows EXE SHA256: $hash"
} finally { $env:APPDATA = $previousAppData; $env:TEMP = $previousTemp; $env:TMP = $previousTmp }
