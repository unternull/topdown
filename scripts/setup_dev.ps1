#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

function Ensure-Pipx {
	if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
		Write-Host "pipx not found; installing..."
		py -m pip install --user pipx
		py -m pipx ensurepath | Out-Null
		Write-Host "Restart your terminal if pipx is not in PATH."
	}
}

Ensure-Pipx

try {
	pipx list | Select-String -Quiet gdtoolkit | Out-Null
	$hasGd = $?
} catch {
	$hasGd = $false
}
if (-not $hasGd) { pipx install "gdtoolkit==4.*" } else { pipx upgrade gdtoolkit }

try {
	pipx list | Select-String -Quiet pre-commit | Out-Null
	$hasPreCommit = $?
} catch {
	$hasPreCommit = $false
}
if (-not $hasPreCommit) { pipx install pre-commit } else { pipx upgrade pre-commit }

pre-commit install

# Vendor GUT (Godot Unit Test) 9.5.0 into topdown/addons/gut
$GUT_VERSION = "9.5.0"
$GUT_URL = "https://github.com/bitwes/Gut/archive/refs/tags/v$GUT_VERSION.zip"
Write-Host "Vendoring GUT v$GUT_VERSION..."
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("gut_" + [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp | Out-Null
$zip = Join-Path $tmp "gut.zip"
Invoke-WebRequest -Uri $GUT_URL -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$gutFolder = Get-ChildItem -Path $tmp -Directory -Filter "Gut-*" | Select-Object -First 1
if (-not $gutFolder) { throw "Could not locate extracted Gut-* folder" }
$src = Join-Path $gutFolder.FullName "addons\gut"
$destRoot = "topdown\addons"
$dest = Join-Path $destRoot "gut"
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
Copy-Item -Recurse -Force $src $dest
Write-Host "GUT installed at $dest"

Write-Host "Setup complete. Try: gdlint topdown, gdformat --check topdown, and run tests via Godot headless."
