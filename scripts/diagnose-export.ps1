param([Parameter(Mandatory=$true)][string]$Godot,[Parameter(Mandatory=$true)][string]$TemplateDirectory,[ValidateSet('baseline','followup')][string]$Mode='baseline')
$ErrorActionPreference='Stop'
$sourceRoot=Split-Path $PSScriptRoot -Parent
$experimentRoot=Join-Path $sourceRoot ('artifacts/export-diagnostics/'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $experimentRoot | Out-Null
$originalAppData=$env:APPDATA; $originalTemp=$env:TEMP; $originalTmp=$env:TMP
$results=@()
try {
    $cases=if($Mode -eq 'baseline'){@('minimal-no-addon','minimal-addon','game-no-addon','game-addon')}else{@('minimal-addon-native-only','minimal-addon-editor-release')}
    foreach($case in $cases) {
        $caseRoot=Join-Path $experimentRoot $case
        New-Item -ItemType Directory -Force $caseRoot | Out-Null
        Copy-Item (Join-Path $sourceRoot 'project.godot') $caseRoot
        Copy-Item (Join-Path $sourceRoot 'export_presets.cfg') $caseRoot
        Copy-Item (Join-Path $sourceRoot 'main.tscn') $caseRoot
        if($case.StartsWith('minimal')) {
            Set-Content (Join-Path $caseRoot 'game.gd') "extends Node3D`n"
        } else {
            $game=Get-Content (Join-Path $sourceRoot 'game.gd') -Raw
            if($case -eq 'game-no-addon') {
                $dummy=@'
class NoGuaAdapter extends RefCounted:
	func attach(_root): pass
	func update(_screen): pass
	func start_inspector_bridge(_port): return true
	func dispose(): pass
'@
                $game=$game.Replace('const Adapter = preload("res://addons/gua/gua_auto_adapter.gd")',$dummy).Replace('var adapter = Adapter.new()','var adapter = NoGuaAdapter.new()')
            }
            Set-Content (Join-Path $caseRoot 'game.gd') $game
        }
        if($case -ne 'minimal-no-addon' -and $case -ne 'game-no-addon') { Copy-Item (Join-Path $sourceRoot 'addons') $caseRoot -Recurse }
        if($case -eq 'minimal-addon-native-only') {
            Get-ChildItem (Join-Path $caseRoot 'addons/gua') -Filter '*.gd' -File | ForEach-Object { Remove-Item -LiteralPath $_.FullName }
        }
        if($case -eq 'minimal-addon-editor-release') {
            $descriptor=Join-Path $caseRoot 'addons/gua/gua.gdextension'
            $contents=Get-Content $descriptor -Raw
            Set-Content $descriptor $contents.Replace('windows.debug.x86_64 = "res://addons/gua/bin/gua_godot.windows.debug.x86_64.dll"','windows.debug.x86_64 = "res://addons/gua/bin/gua_godot.windows.release.x86_64.dll"')
        }
        $env:APPDATA=Join-Path $caseRoot '_runtime'
        $env:TEMP=Join-Path $env:APPDATA 'tmp'; $env:TMP=$env:TEMP
        New-Item -ItemType Directory -Force $env:TEMP | Out-Null
        Set-Content (Join-Path $env:APPDATA '.gdignore') ''
        $templates=Join-Path $env:APPDATA 'Godot/export_templates/4.7.stable'
        New-Item -ItemType Directory -Force $templates | Out-Null
        Copy-Item (Join-Path $TemplateDirectory 'windows_release_x86_64*.exe') $templates
        New-Item -ItemType Directory -Force (Join-Path $caseRoot 'dist') | Out-Null
        Set-Content (Join-Path $caseRoot 'dist/.gdignore') ''
        & $Godot --headless --path $caseRoot --log-file (Join-Path $caseRoot 'editor.log') --export-release 'Windows Desktop' (Join-Path $caseRoot 'dist/FacilityEscape.exe') *> (Join-Path $caseRoot 'console.log')
        $exitCode=$LASTEXITCODE
        $log=Get-Content (Join-Path $caseRoot 'editor.log') -Raw
        $exe=Join-Path $caseRoot 'dist/FacilityEscape.exe'
        $result=@{case=$case;exitCode=$exitCode;packComplete=($log -match '\[ DONE \] savepack');exeExists=(Test-Path $exe);scriptError=($log -match 'SCRIPT ERROR');sha256=if(Test-Path $exe){(Get-FileHash $exe).Hash.ToLowerInvariant()}else{$null}}
        $results+=$result
        $result | ConvertTo-Json | Write-Output
    }
} finally {
    $env:APPDATA=$originalAppData; $env:TEMP=$originalTemp; $env:TMP=$originalTmp
    @{mode=$Mode;godot=(Get-FileHash $Godot).Hash.ToLowerInvariant();os=[Environment]::OSVersion.VersionString;windowsFaultEvents='Not collected: local Application log read denied; no retry';cases=$results} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $experimentRoot 'comparison.json')
    Write-Output "Disposable experiment evidence: $experimentRoot"
}
