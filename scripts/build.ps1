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
        $report.remoteBuildInfo=(Get-Content (Join-Path $root 'artifacts/distribution-smoke/result.json') -Raw|ConvertFrom-Json).buildInfo
    }
    $report.sdkPurpose='DevelopmentRemote test sample; not Shipping or Player-only distribution'
    $report.dllSha256=(Get-FileHash $dll).Hash.ToLowerInvariant()
    $report.remoteValidation=if($Smoke){'Verified actual exported process build-info'}else{'Not executed; use -Smoke'}
    $report|ConvertTo-Json -Depth 8|Set-Content (Join-Path $evidence 'export.json')
    $sourceChanges=@(& git -C $root status --porcelain --untracked-files=no)
    @{schemaVersion=1;kind='facility-development-package';sampleSourceCommit=(& git -C $root rev-parse HEAD);sampleSourceDirty=($sourceChanges.Count -gt 0);sampleSourceChanges=$sourceChanges;gameSourceSha256=(Get-FileHash (Join-Path $root 'game.gd')).Hash.ToLowerInvariant();guaSourceCommit='2e12fb3cfdf822418f349515027d6f620c5ee63b';sdkArchiveSha256='effcad4cfc6083528bee4e469e171047cd9d2d49547a09d16be04845fcda7873';build=$report;files=@(@{path='FacilityEscape.exe';sha256=$report.exeSha256},@{path='gua_godot.windows.release.x86_64.dll';sha256=$report.dllSha256})}|ConvertTo-Json -Depth 10|Set-Content (Join-Path $dist 'facility-build-manifest.json')
    Write-Output "Windows EXE SHA256: $($report.exeSha256)"
} finally {$env:APPDATA=$previousAppData;$env:TEMP=$previousTemp;$env:TMP=$previousTmp}
