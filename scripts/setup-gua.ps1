$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$vendor = Join-Path $root 'vendor'
New-Item -ItemType Directory -Force $vendor | Out-Null
Set-Content (Join-Path $vendor '.gdignore') ''
$archive = Join-Path $vendor 'gua-godot-addon-v1.2.0.zip'
if (!(Test-Path $archive)) {
    Invoke-WebRequest 'https://github.com/gua-project/gua/releases/download/gua-v1.2.0/gua-godot-addon-v1.2.0.zip' -OutFile $archive
}
$expected = 'effcad4cfc6083528bee4e469e171047cd9d2d49547a09d16be04845fcda7873'
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'Gua archive SHA256 mismatch' }
$extract = Join-Path $vendor 'gua-1.2.0'
Expand-Archive $archive -DestinationPath $extract -Force
New-Item -ItemType Directory -Force (Join-Path $root 'addons') | Out-Null
Copy-Item (Join-Path $extract 'addons/gua') (Join-Path $root 'addons') -Recurse -Force
Write-Output "Official Gua 1.2.0 Development/remote-ON test SDK archive verified: $expected. This is not a Shipping/OFF or Player-only package."
