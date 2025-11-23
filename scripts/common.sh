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

# Prompt for yes/no confirmation
# Usage: confirm "Are you sure?" && do_something
confirm() {
    local message="${1:-Are you sure?}"
    local response
    
    while true; do
        read -p "$message [y/N] " -r response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                return 0
                ;;
            [nN][oO]|[nN]|"") 
                return 1
                ;;
            *)
                print_warning "Please answer yes or no."
                ;;
        esac
    done
}

# Run SSH command on remote host with error handling
# Usage: run_ssh <host> <command>
run_ssh() {
    local host="$1"
    local cmd="$2"
    
    print_info "Running command on $host..."
    
    if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$host" "$cmd"; then
        print_error "SSH command failed on $host"
        return 1
    fi
    
    return 0
}

# Ensure Docker is installed on local or remote system
# Usage: ensure_docker_installed [ssh_host]
ensure_docker_installed() {
    local ssh_host="${1:-}"
    local cmd_prefix=""
    
    if [ -n "$ssh_host" ]; then
        cmd_prefix="ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new $ssh_host"
        print_header "Ensuring Docker is installed on $ssh_host"
    else
        print_header "Ensuring Docker is installed locally"
    fi
    
    # Check if Docker is already installed
    if $cmd_prefix command -v docker &> /dev/null; then
        print_info "Docker is already installed"
        
        # Check if docker compose plugin is available
        if $cmd_prefix docker compose version &> /dev/null; then
            print_info "Docker Compose plugin is already installed"
            return 0
        else
            print_warning "Docker Compose plugin not found, will install it"
        fi
    else
        print_info "Docker not found, installing Docker CE..."
    fi
    
    # For remote installation, we need to create a script and execute it
    if [ -n "$ssh_host" ]; then
        print_info "Installing Docker on remote host $ssh_host..."
        
        # Create installation script
        local install_script=$(cat <<'EOFSCRIPT'
set -euo pipefail

# Update package index
sudo apt-get update -qq

# Install prerequisites
sudo apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
sudo apt-get update -qq

# Install Docker Engine and compose plugin
sudo apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker "$USER"

echo "Docker installation complete!"
EOFSCRIPT
)
        
        # Execute installation script on remote host
        if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$ssh_host" "bash -s" <<< "$install_script"; then
            print_error "Docker installation failed on $ssh_host"
            return 1
        fi
        
        print_info "Docker installed successfully on $ssh_host"
        print_warning "User may need to log out and back in on $ssh_host for group changes to take effect"
    else
        # Local installation - use existing install_docker function
        install_docker
    fi
    
    return 0
}
