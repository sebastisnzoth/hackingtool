#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV="$ROOT/.venv"
LOCAL="$ROOT/.local"
CACHE="$ROOT/.cache"

mkdir -p "$LOCAL" "$CACHE/pip" "$CACHE/uv" "$LOCAL/uv-tools" "$LOCAL/uv-python"

export PIP_CACHE_DIR="$CACHE/pip"
export UV_CACHE_DIR="$CACHE/uv"
export UV_TOOL_DIR="$LOCAL/uv-tools"
export UV_PYTHON_INSTALL_DIR="$LOCAL/uv-python"
export XDG_CACHE_HOME="$CACHE"

echo "== HackingTool local bootstrap =="
echo "repo: $ROOT"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "ERROR: $PYTHON_BIN was not found."
  exit 1
fi

"$PYTHON_BIN" - <<'PY'
import sys
if sys.version_info < (3, 10):
    raise SystemExit(f"ERROR: Python 3.10+ required, found {sys.version.split()[0]}")
print("python:", sys.version.split()[0])
PY

# Reuse a healthy local environment without touching the network.
if [ -x "$VENV/bin/python" ] && "$VENV/bin/python" - <<'PY' >/dev/null 2>&1
import rich, yaml, platformdirs, prompt_toolkit, dotenv, hackingtool
PY
then
  echo "Existing .venv is healthy."
  echo "Run: $VENV/bin/hackingtool"
  exit 0
fi

# Dependency installation needs package-index access at least once.
if ! "$PYTHON_BIN" - <<'PY'
import socket
socket.getaddrinfo("pypi.org", 443)
PY
then
  cat <<'EOF'
ERROR: DNS cannot resolve pypi.org.

The project itself is ready, but Python cannot download its runtime dependencies.
This script deliberately keeps all installs/caches inside the repository and does
not require sudo or writable Homebrew directories.

Fix the Mac/network DNS first, then run:
  ./scripts/bootstrap-local.sh

Useful checks:
  scutil --dns
  ping -c 1 pypi.org
  curl -I https://pypi.org/simple/
EOF
  exit 2
fi

if command -v uv >/dev/null 2>&1; then
  echo "Using uv with project-local cache..."
  uv venv "$VENV" --python "$PYTHON_BIN"
  uv pip install --python "$VENV/bin/python" -e .
else
  echo "uv not found; using stdlib venv + pip..."
  "$PYTHON_BIN" -m venv "$VENV"
  "$VENV/bin/python" -m pip install --upgrade pip setuptools wheel
  "$VENV/bin/python" -m pip install -e .
fi

echo
echo "Installation complete."
echo "Run HackingTool with:"
echo "  $VENV/bin/hackingtool"
echo
echo "Or activate the environment:"
echo "  source $VENV/bin/activate"
echo "  hackingtool"
