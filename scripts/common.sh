#!/usr/bin/env bash
set -euo pipefail

# Simple header
print_header() {
  local msg="$1"
  echo
  echo "============================================================"
  echo "  $msg"
  echo "============================================================"
  echo
}

# Ensure required command exists
require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' not found in PATH" >&2
    exit 1
  fi
}

# Yes/No confirmation
confirm() {
  local prompt="${1:-Are you sure?} [y/N] "
  read -r -p "$prompt" ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *)                 return 1 ;;
  esac
}

# Run a command over SSH with logging
run_ssh() {
  local host="$1"; shift
  echo "[SSH] $host: $*"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$host" "$@"
}

# Install Docker on a remote host (Debian/Raspbian/Ubuntu) using get.docker.com
install_docker_remote() {
  local host="$1"

  run_ssh "$host" 'if command -v docker >/dev/null 2>&1; then
    echo "[Remote] Docker already installed."
    exit 0
  fi'

  echo "[INFO] Installing Docker on $host (using get.docker.com)..."
  run_ssh "$host" 'curl -fsSL https://get.docker.com | sh'
  run_ssh "$host" 'sudo usermod -aG docker "$USER" || true'
  echo "[INFO] Docker install triggered on $host. You may need to log out/in on that host."
}
