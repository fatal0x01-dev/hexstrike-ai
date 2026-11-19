#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Error: $PYTHON_BIN was not found." >&2
  exit 1
fi

if ! command -v pipenv >/dev/null 2>&1; then
  echo "Pipenv is not installed; installing it for the current user..."
  "$PYTHON_BIN" -m pip install --user pipenv
fi

PIPENV_BIN="$(command -v pipenv || true)"
if [[ -z "$PIPENV_BIN" ]]; then
  PIPENV_BIN="$HOME/.local/bin/pipenv"
fi

if [[ ! -x "$PIPENV_BIN" ]]; then
  echo "Error: Pipenv was installed but could not be located at $PIPENV_BIN." >&2
  echo "Ensure $HOME/.local/bin is in PATH." >&2
  exit 1
fi

export PIPENV_VENV_IN_PROJECT=1
"$PIPENV_BIN" --python "$PYTHON_BIN"
"$PIPENV_BIN" install --requirements requirements.txt

cat <<EOF

Pipenv environment is ready.
Run HexStrike with:
  pipenv run ./run_hexstrike.sh

Run the MCP client too:
  pipenv run ./run_hexstrike.sh --mcp
EOF
