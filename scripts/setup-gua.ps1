$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$vendor = Join-Path $root 'vendor'
New-Item -ItemType Directory -Force $vendor | Out-Null
Set-Content (Join-Path $vendor '.gdignore') ''
$archive = Join-Path $vendor 'gua-godot-addon-v1.1.2.zip'
if (!(Test-Path $archive)) {
    Invoke-WebRequest 'https://github.com/gua-project/gua/releases/download/gua-v1.1.2/gua-godot-addon-v1.1.2.zip' -OutFile $archive
}
$expected = '19f89058ca60e48c74a7327da31c0e011b4c053acfda8e5b8e2e2b1fc90ae8c4'
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'Gua archive SHA256 mismatch' }
$extract = Join-Path $vendor 'gua-1.1.2'
Expand-Archive $archive -DestinationPath $extract -Force
New-Item -ItemType Directory -Force (Join-Path $root 'addons') | Out-Null
Copy-Item (Join-Path $extract 'addons/gua') (Join-Path $root 'addons') -Recurse -Force
Write-Output "Official Gua 1.1.2 verified: $expected"
