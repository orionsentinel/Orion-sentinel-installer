#!/usr/bin/env bash
set -euo pipefail

#
# Common utilities for Orion Sentinel installer scripts
# All scripts should source this file for shared functionality
#

# ============================================================
# Output Helpers
# ============================================================

# Print a section header with clear visual separation
print_header() {
  local msg="$1"
  echo
  echo "============================================================"
  echo "  $msg"
  echo "============================================================"
  echo
}

# Print an info message
print_info() {
  echo "[INFO] $*"
}

# Print an error message to stderr
print_error() {
  echo "[ERROR] $*" >&2
}

# Print a warning message
print_warning() {
  echo "[WARN] $*"
}

# ============================================================
# Validation Helpers
# ============================================================

# Ensure required command exists, exit if not found
require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    print_error "Required command '$cmd' not found in PATH"
    exit 1
  fi
}

# Yes/No confirmation prompt
confirm() {
  local prompt="${1:-Are you sure?} [y/N] "
  read -r -p "$prompt" ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *)                 return 1 ;;
  esac
}

# ============================================================
# SSH Helpers
# ============================================================

# Run a command over SSH with error handling and logging
run_ssh() {
  local host="$1"; shift
  print_info "Running on $host: $*"
  if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$host" "$@"; then
    print_error "SSH command failed on $host"
    return 1
  fi
}

# ============================================================
# Docker Installation Helpers
# ============================================================

# Install Docker locally using official Docker CE repository (not convenience script)
# This provides better control and follows Docker's recommended installation method
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    print_info "Docker already installed (version: $(docker --version))"
    return 0
  fi

  print_header "Installing Docker CE"
  print_info "Installing Docker using official Docker CE repository..."
  
  # Detect OS
  if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    OS=$ID
  else
    print_error "Cannot detect OS. /etc/os-release not found."
    exit 1
  fi

  # Install prerequisites
  print_info "Installing prerequisites..."
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  # Add Docker's official GPG key
  print_info "Adding Docker GPG key..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${OS}/gpg" | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Set up the repository
  print_info "Adding Docker repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS} \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker Engine
  print_info "Installing Docker Engine..."
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Add current user to docker group
  print_info "Adding current user to docker group..."
  sudo usermod -aG docker "$USER" || true

  print_info "Docker installation complete!"
  print_warning "You may need to log out and back in for group changes to take effect."
  print_info "Or run: newgrp docker"
}

# Ensure Docker is installed (locally)
ensure_docker_installed() {
  install_docker
}

# Install Docker on a remote host using official Docker CE repository
install_docker_remote() {
  local host="$1"

  # Check if Docker is already installed
  if run_ssh "$host" 'command -v docker >/dev/null 2>&1'; then
    print_info "Docker already installed on $host"
    return 0
  fi

  print_header "Installing Docker on $host"
  print_info "Installing Docker CE on remote host..."

  # Run the installation script remotely
  run_ssh "$host" 'bash -s' <<'REMOTE_SCRIPT'
set -euo pipefail

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "ERROR: Cannot detect OS" >&2
  exit 1
fi

# Install prerequisites
echo "[INFO] Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
echo "[INFO] Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/${OS}/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo "[INFO] Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS} \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
echo "[INFO] Installing Docker Engine..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
echo "[INFO] Adding user to docker group..."
sudo usermod -aG docker "$USER" || true

echo "[INFO] Docker installation complete!"
REMOTE_SCRIPT

  print_info "Docker installed on $host. User may need to re-login for group changes."
}

# Ensure Docker is installed on a remote host
ensure_docker_installed_remote() {
  local host="$1"
  install_docker_remote "$host"
}

# ============================================================
# Repository Helpers
# ============================================================

# Clone a git repository or update it if it already exists
# Usage: clone_repo_if_missing <repo_url> <target_dir> [branch]
clone_repo_if_missing() {
  local repo_url="$1"
  local target_dir="$2"
  local branch="${3:-main}"

  if [ -d "$target_dir" ]; then
    print_info "Repository already exists at $target_dir, updating..."
    if ! (cd "$target_dir" && git pull); then
      print_warning "Git pull failed, but continuing..."
    fi
  else
    print_info "Cloning repository to $target_dir..."
    local parent_dir
    parent_dir=$(dirname "$target_dir")
    mkdir -p "$parent_dir"
    if ! git clone --branch "$branch" "$repo_url" "$target_dir"; then
      print_error "Failed to clone repository from $repo_url"
      return 1
    fi
  fi
}

# ============================================================
# Network Helpers
# ============================================================

# Get the local IP address (best effort)
get_local_ip() {
  # Try to get IP from default route interface
  local ip
  ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "")
  
  if [ -z "$ip" ]; then
    # Fallback: get first non-loopback IP
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
  fi
  
  echo "$ip"
}
