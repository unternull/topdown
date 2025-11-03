## TopDown – Development Guide

### Prerequisites
- **Godot 4.x** (project targets Godot 4; install from the official site)
- **Python 3** and **pip** available on your PATH
- **pipx** (recommended for isolated CLI tools)
- **Git**

Toolkit used: [GDScript Toolkit (gdlint/gdformat/gdparse/gdradon)](https://github.com/Scony/godot-gdscript-toolkit)

### Quick start (after cloning)
macOS/Linux:
```bash
bash scripts/setup_dev.sh
```

Windows (PowerShell):
```powershell
./scripts/setup_dev.ps1
```

What this does:
- Installs `pipx` (if missing), then installs/updates `gdtoolkit==4.*` and `pre-commit`
- Installs git hooks to run linter/formatter checks on commit
- Vendors GUT (Godot Unit Test) 9.5.0 into `topdown/addons/gut`

Open the project in Godot by opening the `topdown/project.godot` project file.

### Developer commands
Convenient shortcuts are provided via the `Makefile` (macOS/Linux). Run these from the repository root:

```bash
make lint           # Run gdlint on the project sources
make format         # Apply gdformat to sources (in-place)
make format-check   # Verify formatting (no changes)
make parse          # Run gdparse on sources (parser output)
make cc             # Cyclomatic complexity (gdradon)
make hooks          # Re-install pre-commit hooks
make test           # Run unit tests via GUT in headless Godot (or GODOT=/Applications/Godot.app/Contents/MacOS/Godot make test)
```

On Windows without `make`, you can directly call the tools, e.g.:
```powershell
gdlint topdown
gdformat --check topdown
godot --headless --path topdown --script res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

### On-commit checks (git hooks)
The repository includes a `.pre-commit-config.yaml` that runs:
- `gdlint` (linter)
- `gdformat --check` (format verification)

Commits will be blocked if either fails. To auto-fix formatting before committing, run `make format` (or `gdformat topdown`).

### Continuous Integration
GitHub Actions workflow at `.github/workflows/static-checks.yml` runs the same checks (`gdformat --check`, `gdlint`) on pushes and pull requests to protect main branches.

### Unit tests

- Framework: GUT 9.5.0 for Godot 4.5+ ([repo](https://github.com/bitwes/Gut))
- Tests live in `topdown/test/` (example: `test_grid.gd`).
- Run on macOS/Linux:
  ```bash
  make test
  # Or specify a custom Godot binary
  GODOT=/Applications/Godot.app/Contents/MacOS/Godot make test
  ```
- Run on Windows (PowerShell):
  ```powershell
  godot --headless --path topdown --script res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit
  ```

### Lint/format exclusions

- Third-party code under `topdown/addons/` is excluded from lint/format:
  - Make targets lint/format/parse/cc operate on `topdown/scripts`, `topdown/scenes`, `topdown/test` only
  - Pre-commit excludes `^topdown/addons/`
  - CI workflow runs tools only on those source directories

### Updating tools
If you need to update to the latest 4.x toolkit:
```bash
pipx upgrade gdtoolkit
pipx upgrade pre-commit
```
Re-run `make hooks` if hooks ever need reinstalling.

### Troubleshooting
- `pipx: command not found`: re-run the setup script and restart your terminal to refresh PATH.
- `gdformat`/`gdlint` not found: ensure `pipx ensurepath` took effect (open a new shell) or run the setup script again.
- Hook didn’t run: run `make hooks` to reinstall pre-commit hooks.

### Cursor rules
This repo includes always-on Cursor rules to match gdtoolkit and the project’s GDScript style.

- Rules file: `topdown/.cursor/rules/development/general.mdc`
- Effect: AI edits are steered to be `gdformat`-clean and pass `gdlint`, with our naming, typing, and Godot scene conventions.
- If edits fail checks, run `make format` then `make lint` and accept `gdformat`’s layout.
