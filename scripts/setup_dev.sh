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

# Vendor GUT (Godot Unit Test) 9.5.0 into topdown/addons/gut
GUT_VERSION="9.5.0"
GUT_URL="https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.zip"

echo "Vendoring GUT v${GUT_VERSION}..."
TMP_DIR="$(mktemp -d)"
ZIP_FILE="${TMP_DIR}/gut.zip"
if command -v curl >/dev/null 2>&1; then
	curl -L -o "${ZIP_FILE}" "${GUT_URL}"
elif command -v wget >/dev/null 2>&1; then
	wget -O "${ZIP_FILE}" "${GUT_URL}"
else
	echo "Error: need curl or wget to download GUT." >&2
	exit 1
fi

# Extract zip (prefer unzip, fallback to Python)
if command -v unzip >/dev/null 2>&1; then
	unzip -q "${ZIP_FILE}" -d "${TMP_DIR}"
else
	python3 - <<'PY'
import sys, zipfile, os
zip_path = sys.argv[1]
dst = sys.argv[2]
with zipfile.ZipFile(zip_path, 'r') as zf:
	zf.extractall(dst)
print('Extracted to', dst)
PY
	"${ZIP_FILE}" "${TMP_DIR}"
fi

SRC_DIR="$(find "${TMP_DIR}" -maxdepth 4 -type d -path "*/addons/gut" | head -n1)"
if [ -z "${SRC_DIR}" ]; then
	echo "Error: could not locate addons/gut in the downloaded archive" >&2
	exit 1
fi

mkdir -p topdown/addons
rm -rf topdown/addons/gut
cp -R "${SRC_DIR}" topdown/addons/gut
echo "GUT installed at topdown/addons/gut"

echo "Setup complete. Try: make lint, make format, make format-check, make test"
