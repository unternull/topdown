#!/usr/bin/env bash
set -euo pipefail

# Ensure pipx
if ! command -v pipx >/dev/null 2>&1; then
	echo "pipx not found; installing..."
	python3 -m pip install --user pipx
	python3 -m pipx ensurepath || true
	echo "Restart your shell if pipx is not in PATH."
fi

# Install tools
if ! pipx list | grep -q gdtoolkit; then
	pipx install "gdtoolkit==4.*"
else
	pipx upgrade gdtoolkit || true
fi

if ! pipx list | grep -q pre-commit; then
	pipx install pre-commit
else
	pipx upgrade pre-commit || true
fi

# Install git hooks
pre-commit install

echo "Setup complete. Try: make lint, make format, make format-check"
