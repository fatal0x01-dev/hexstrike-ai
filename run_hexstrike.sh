#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HEXSTRIKE_HOST="${HEXSTRIKE_HOST:-127.0.0.1}"
HEXSTRIKE_PORT="${HEXSTRIKE_PORT:-8888}"
LLAMA_API_URL="${LLAMA_API_URL:-https://truck-kissable-caption.ngrok-free.dev/v1}"
LLAMA_API_KEY_FILE="${LLAMA_API_KEY_FILE:-$HOME/.config/llama-ngrok/api-key.txt}"
LLAMA_MODEL="${LLAMA_MODEL:-/home/fatal0x01/models/qwen2.5-coder-14b-instruct-q4_k_m.gguf}"
LLAMA_REQUEST_TIMEOUT="${LLAMA_REQUEST_TIMEOUT:-300}"
VENV_DIR="${VENV_DIR:-$SCRIPT_DIR/hexstrike-env}"
START_MCP=false
DEBUG_ARGS=()

usage() {
  cat <<'USAGE'
Usage: ./run_hexstrike.sh [options]

Options:
  --mcp                 Start hexstrike_mcp.py after the API server is healthy
  --debug               Enable debug mode for both processes
  --host HOST           HexStrike bind host (default: 127.0.0.1)
  --port PORT           HexStrike API port (default: 8888)
  --llama-url URL       llama.cpp OpenAI-compatible base URL
  --llama-key-file PATH llama.cpp bearer key file
  --llama-model MODEL   llama.cpp model ID
  --venv PATH           Python virtual environment path (default: ./hexstrike-env)
  -h, --help            Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mcp) START_MCP=true; shift ;; 
    --debug) DEBUG_ARGS=(--debug); shift ;; 
    --host) HEXSTRIKE_HOST="$2"; shift 2 ;; 
    --port) HEXSTRIKE_PORT="$2"; shift 2 ;; 
    --llama-url) LLAMA_API_URL="$2"; shift 2 ;; 
    --llama-key-file) LLAMA_API_KEY_FILE="$2"; shift 2 ;; 
    --llama-model) LLAMA_MODEL="$2"; shift 2 ;; 
    --venv) VENV_DIR="$2"; shift 2 ;; 
    -h|--help) usage; exit 0 ;; 
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;; 
  esac
done

if [[ -f "$VENV_DIR/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
else
  echo "Warning: virtual environment not found at $VENV_DIR; using $(command -v python3)" >&2
fi

if [[ -f "$LLAMA_API_KEY_FILE" ]]; then
  export LLAMA_API_KEY="$(tr -d '\r\n' < "$LLAMA_API_KEY_FILE")"
else
  echo "Warning: llama API key file not found: $LLAMA_API_KEY_FILE" >&2
fi

export HEXSTRIKE_HOST
export HEXSTRIKE_PORT
export LLAMA_API_URL
export LLAMA_API_KEY_FILE
export LLAMA_MODEL
export LLAMA_REQUEST_TIMEOUT

SERVER_PID=""
MCP_PID=""
cleanup() {
  if [[ -n "$MCP_PID" ]] && kill -0 "$MCP_PID" 2>/dev/null; then
    kill "$MCP_PID" 2>/dev/null || true
  fi
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

python3 hexstrike_server.py --port "$HEXSTRIKE_PORT" "${DEBUG_ARGS[@]}" &
SERVER_PID=$!

for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${HEXSTRIKE_PORT}/health" >/dev/null 2>&1; then
    echo "HexStrike API ready at http://127.0.0.1:${HEXSTRIKE_PORT}"
    break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    wait "$SERVER_PID"
    exit $?
  fi
  sleep 1
done

if [[ "$START_MCP" == true ]]; then
  python3 hexstrike_mcp.py --server "http://127.0.0.1:${HEXSTRIKE_PORT}" "${DEBUG_ARGS[@]}" &
  MCP_PID=$!
fi

wait "$SERVER_PID"
