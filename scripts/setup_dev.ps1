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

Write-Host "Setup complete. Try: gdlint topdown, gdformat --check topdown"
