#!/usr/bin/env bash
set -euo pipefail

# Common helper functions for Orion Sentinel installer scripts

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Print a formatted header
print_header() {
    local message="$1"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  ${message}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Print info message
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Print error message
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if a required command exists
# Usage: require_cmd <command_name>
require_cmd() {
    if ! command -v "$1" &>/dev/null 2>&1; then
        print_error "Required command '$1' not found. Please install it and retry."
        exit 1
    fi
}

# Yes/No confirmation
# Usage: confirm "Are you sure?" && do_something
confirm() {
    local prompt="${1:-Are you sure?} [y/N] "
    read -r -p "$prompt" ans
    case "$ans" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *)                 return 1 ;;
    esac
}

# Run a command over SSH with nice logging
# Usage: run_ssh <host> <command> [args...]
# NOTE: This uses StrictHostKeyChecking=accept-new which automatically accepts
# new host keys. For enhanced security in production environments, consider:
# 1. Pre-populating known_hosts with ssh-keyscan
# 2. Using StrictHostKeyChecking=ask to prompt users
# 3. Verifying host keys through a separate secure channel
run_ssh() {
    local host="$1"; shift
    echo "[SSH] $host: $*"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$host" "$@"
}

# Install Docker on a remote host (Debian/Raspbian/Ubuntu) in a simple way.
# Usage: install_docker_remote <host>
# 
# SECURITY NOTE: This uses the get.docker.com convenience script for simplicity.
# For production or security-critical environments, consider:
# 1. Using the full Docker repository installation method (see common.sh install_docker())
# 2. Verifying the script integrity before execution
# 3. Running the script through a review process
# 
# The get.docker.com script is maintained by Docker and widely used, but piping
# curl output directly to sh bypasses integrity verification. For more secure
# installations, download and review the script first, or use the official
# repository method as shown in the install_docker() function.
install_docker_remote() {
    local host="$1"

    run_ssh "$host" 'if command -v docker >/dev/null 2>&1; then
        echo "[Remote] Docker already installed."
        exit 0
    fi'

    echo "[INFO] Installing Docker on $host (using get.docker.com)..."
    echo "[INFO] Note: Using convenience script. See function docs for security considerations."
    run_ssh "$host" 'curl -fsSL https://get.docker.com | sh'
    # Add current user on the Pi to docker group (usually "pi" or same ssh user)
    run_ssh "$host" 'sudo usermod -aG docker "$USER" || true'
    echo "[INFO] Docker install triggered on $host. You may need to log out/in on that host."
}

# Install Docker CE and compose plugin if not already installed
install_docker() {
    print_header "Checking Docker Installation"
    
    if command -v docker &> /dev/null; then
        print_info "Docker is already installed (version: $(docker --version))"
        
        # Check if docker compose plugin is available
        if docker compose version &> /dev/null; then
            print_info "Docker Compose plugin is already installed (version: $(docker compose version))"
            return 0
        else
            print_warning "Docker Compose plugin not found, will install it"
        fi
    else
        print_info "Docker not found, installing Docker CE..."
    fi
    
    # Update package index
    print_info "Updating package index..."
    sudo apt-get update -qq
    
    # Install prerequisites
    print_info "Installing prerequisites..."
    sudo apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    print_info "Adding Docker's official GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        # Download Docker's GPG key and verify fingerprint
        # Docker's official GPG key fingerprint: 9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
        local temp_gpg="/tmp/docker-gpg.tmp"
        curl -fsSL https://download.docker.com/linux/debian/gpg -o "$temp_gpg"
        
        # Verify the key fingerprint
        local key_fingerprint
        key_fingerprint=$(gpg --with-colons --import-options show-only --import < "$temp_gpg" 2>/dev/null | grep fpr | head -1 | cut -d: -f10)
        
        # Check if fingerprint extraction was successful
        if [ -z "$key_fingerprint" ]; then
            print_error "Failed to extract GPG key fingerprint"
            rm "$temp_gpg"
            return 1
        fi
        
        # Docker's official key fingerprint (without spaces)
        local expected_fingerprint="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
        
        if [ "$key_fingerprint" = "$expected_fingerprint" ]; then
            print_info "GPG key fingerprint verified successfully"
            cat "$temp_gpg" | sudo gpg --dearmor | sudo tee /etc/apt/keyrings/docker.gpg > /dev/null
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            rm "$temp_gpg"
        else
            print_error "GPG key fingerprint verification failed!"
            print_error "Expected: $expected_fingerprint"
            print_error "Got: $key_fingerprint"
            rm "$temp_gpg"
            return 1
        fi
    fi
    
    # Set up the repository
    print_info "Setting up Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    sudo apt-get update -qq
    
    # Install Docker Engine and compose plugin
    print_info "Installing Docker Engine and Compose plugin..."
    sudo apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    # Add current user to docker group
    print_info "Adding current user to docker group..."
    sudo usermod -aG docker "$USER"
    
    print_info "Docker installation complete!"
    print_warning "You may need to log out and back in for group changes to take effect"
    print_warning "Or run: newgrp docker"
    
    # Verify installation
    if docker --version && docker compose version; then
        print_info "Docker and Docker Compose installed successfully!"
    else
        print_error "Docker installation verification failed"
        return 1
    fi
}

# Clone a git repository if it doesn't already exist
# Usage: clone_repo_if_missing <repo_url> <target_dir> [branch]
clone_repo_if_missing() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-}"
    local original_dir
    original_dir="$(pwd)"
    
    if [ -d "$target_dir" ]; then
        print_info "Repository already exists at: $target_dir"
        
        # Check if it's actually a git repository
        if [ -d "$target_dir/.git" ] || (cd "$target_dir" && git rev-parse --is-inside-work-tree &>/dev/null); then
            print_info "Pulling latest changes..."
            (
                cd "$target_dir" || return 1
                git pull || print_warning "Could not pull latest changes (you may have local modifications)"
            )
        else
            print_warning "Directory exists but is not a git repository: $target_dir"
            print_warning "Skipping git pull. Please verify the directory manually."
        fi
    else
        print_info "Cloning repository from: $repo_url"
        if [ -n "$branch" ]; then
            print_info "Branch: $branch"
        fi
        print_info "Target directory: $target_dir"
        
        # Create parent directory if it doesn't exist
        local parent_dir
        parent_dir="$(dirname "$target_dir")"
        mkdir -p "$parent_dir"
        
        # Clone the repository
        local clone_cmd="git clone"
        if [ -n "$branch" ]; then
            clone_cmd="$clone_cmd --branch $branch"
        fi
        
        if $clone_cmd "$repo_url" "$target_dir"; then
            print_info "Repository cloned successfully!"
        else
            print_error "Failed to clone repository"
            return 1
        fi
    fi
    
    # Return to original directory (don't fail the function if this fails)
    cd "$original_dir" || print_warning "Failed to return to original directory: $original_dir"
    return 0
}

# Get the local IP address
get_local_ip() {
    # Try to get IP from hostname command
    hostname -I | awk '{print $1}'
}

# Wait for user confirmation
wait_for_confirmation() {
    local message="${1:-Press Enter to continue...}"
    echo ""
    read -p "$message" -r
    echo ""
}
