param([Parameter(Mandatory=$true)][string]$Godot,[Parameter(Mandatory=$true)][string]$TemplateDirectory,[switch]$Smoke)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$previousAppData=$env:APPDATA; $previousTemp=$env:TEMP; $previousTmp=$env:TMP
try {
    $env:APPDATA=Join-Path $root '.runtime'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    Set-Content (Join-Path $env:APPDATA '.gdignore') ''
    $env:TEMP=Join-Path $env:APPDATA 'tmp'; $env:TMP=$env:TEMP
    New-Item -ItemType Directory -Force $env:TEMP | Out-Null
    $templates=Join-Path $env:APPDATA 'Godot/export_templates/4.7.stable'
    New-Item -ItemType Directory -Force $templates | Out-Null
    Copy-Item (Join-Path $TemplateDirectory 'windows_release_x86_64*.exe') $templates -Force
    $dist=Join-Path $root 'dist'; New-Item -ItemType Directory -Force $dist | Out-Null
    Set-Content (Join-Path $dist '.gdignore') ''
    foreach($name in @('FacilityEscape.exe','gua_godot.windows.release.x86_64.dll')) {
        $old=Join-Path $dist $name
        if(Test-Path -LiteralPath $old){Remove-Item -LiteralPath $old}
    }
    & $Godot --headless --path $root --log-file (Join-Path $env:APPDATA 'godot-export.log') --export-release 'Windows Desktop' (Join-Path $dist 'FacilityEscape.exe')
    $exitCode=$LASTEXITCODE
    $log=Get-Content (Join-Path $env:APPDATA 'godot-export.log') -Raw
    $evidence=Join-Path $root 'artifacts/build';New-Item -ItemType Directory -Force $evidence|Out-Null
    Copy-Item (Join-Path $env:APPDATA 'godot-export.log') (Join-Path $evidence 'editor.log') -Force
    $exe=Join-Path $dist 'FacilityEscape.exe';$dll=Join-Path $dist 'gua_godot.windows.release.x86_64.dll'
    $report=@{kind='package-build';exportExitCode=$exitCode;packComplete=($log -match '\[ DONE \] savepack');exeExists=(Test-Path $exe);dllExists=(Test-Path $dll);exeSha256=if(Test-Path $exe){(Get-FileHash $exe).Hash.ToLowerInvariant()}else{$null};playtestE2E='not executed'}
    $report|ConvertTo-Json|Set-Content (Join-Path $evidence 'export.json')
    if($env:GITHUB_STEP_SUMMARY){"Export exit: $exitCode. Source regressions and limited smoke are separate outcomes; Playtest E2E is not executed."|Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY}
    if($exitCode -ne 0){throw "Godot export failed: $exitCode; see artifacts/build/export.json and docs/export-diagnosis.md"}
    if(!$report.exeExists -or !$report.dllExists -or !$report.packComplete -or $log -match 'SCRIPT ERROR'){throw 'Export output is incomplete'}
    if($Smoke){
        & node (Join-Path $root 'tests/distribution-smoke.mjs') $dist
        if($LASTEXITCODE -ne 0){throw 'Limited distribution smoke failed'}
    }
    Write-Output "Windows EXE SHA256: $($report.exeSha256)"
} finally {$env:APPDATA=$previousAppData;$env:TEMP=$previousTemp;$env:TMP=$previousTmp}
