#!/usr/bin/env bash
set -euo pipefail

# Orchestrator script for installing Orion Sentinel on remote Raspberry Pis
# This script runs on your local machine and installs components on remote Pis via SSH

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration (can be overridden via environment variables)
readonly ORION_BASE_DIR="${ORION_BASE_DIR:-$HOME/orion}"
readonly DNS_REPO_URL="${DNS_REPO_URL:-https://github.com/yorgosroussakis/rpi-ha-dns-stack.git}"
readonly DNS_REPO_BRANCH="${DNS_REPO_BRANCH:-main}"
readonly NSM_REPO_URL="${NSM_REPO_URL:-https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai.git}"
readonly NSM_REPO_BRANCH="${NSM_REPO_BRANCH:-main}"

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --pi1 <hostname>    Hostname or IP of Pi #1 (DNS)"
    echo "  --pi2 <hostname>    Hostname or IP of Pi #2 (NSM)"
    echo "  --dns-only          Only set up Pi #1 (DNS)"
    echo "  --nsm-only          Only set up Pi #2 (NSM)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --pi1 pi1.local --pi2 pi2.local"
    echo "  $0 --pi1 192.168.1.10 --pi2 192.168.1.11"
    echo "  $0 --pi1 pi-dns.local --dns-only"
    echo ""
    echo "Note: This script requires SSH access to the target Pis."
    echo "      Set up SSH keys beforehand for passwordless access."
}

# Helper function to clone or update a repository on remote host
# Usage: clone_or_update_remote <host> <repo_url> <target_dir> <branch>
clone_or_update_remote() {
    local host="$1"
    local repo_url="$2"
    local target_dir="$3"
    local branch="$4"
    
    run_ssh "$host" "mkdir -p $ORION_BASE_DIR"
    
    # Use a here-document for better readability of the remote command
    run_ssh "$host" bash <<EOF
        if [ -d "$target_dir" ]; then
            cd "$target_dir" && git pull
        else
            git clone --branch "$branch" "$repo_url" "$target_dir"
        fi
EOF
}

setup_dns_pi() {
    local host="$1"
    
    print_header "Setting up Pi #1 (DNS) on $host"
    
    # Install Docker on remote host
    echo "[INFO] Installing Docker on $host..."
    install_docker_remote "$host"
    
    # Clone the DNS repository on remote host
    echo "[INFO] Cloning DNS repository on $host..."
    clone_or_update_remote "$host" "$DNS_REPO_URL" "$ORION_BASE_DIR/rpi-ha-dns-stack" "$DNS_REPO_BRANCH"
    
    # Run the DNS install script
    echo "[INFO] Running DNS installation script on $host..."
    run_ssh "$host" "cd $ORION_BASE_DIR/rpi-ha-dns-stack && bash scripts/install.sh" || {
        echo "[WARN] DNS install script not found or failed"
        echo "[INFO] You may need to configure and start services manually on $host"
    }
    
    echo "[INFO] DNS setup complete on $host!"
    echo "[INFO] Access Pi-hole admin at: http://$host/admin"
}

setup_nsm_pi() {
    local host="$1"
    
    print_header "Setting up Pi #2 (NSM) on $host"
    
    # Install Docker on remote host
    echo "[INFO] Installing Docker on $host..."
    install_docker_remote "$host"
    
    # Clone the NSM repository on remote host
    echo "[INFO] Cloning NSM repository on $host..."
    clone_or_update_remote "$host" "$NSM_REPO_URL" "$ORION_BASE_DIR/Orion-sentinel-netsec-ai" "$NSM_REPO_BRANCH"
    
    # Run the NSM install script
    echo "[INFO] Running NSM installation script on $host..."
    run_ssh "$host" "cd $ORION_BASE_DIR/Orion-sentinel-netsec-ai && bash scripts/install.sh" || {
        echo "[WARN] NSM install script not found or failed"
        echo "[INFO] You may need to configure and start services manually on $host"
    }
    
    echo "[INFO] NSM setup complete on $host!"
    echo "[INFO] Access Grafana at: http://$host:3000"
}

main() {
    local pi1_host=""
    local pi2_host=""
    local dns_only=false
    local nsm_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --pi1)
                pi1_host="$2"
                shift 2
                ;;
            --pi2)
                pi2_host="$2"
                shift 2
                ;;
            --dns-only)
                dns_only=true
                shift
                ;;
            --nsm-only)
                nsm_only=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Validate arguments
    if [ -z "$pi1_host" ] && [ -z "$pi2_host" ]; then
        echo "ERROR: At least one Pi must be specified (--pi1 or --pi2)" >&2
        print_usage
        exit 1
    fi
    
    if [ "$dns_only" = true ] && [ "$nsm_only" = true ]; then
        echo "ERROR: Cannot specify both --dns-only and --nsm-only" >&2
        print_usage
        exit 1
    fi
    
    if [ "$dns_only" = true ] && [ -z "$pi1_host" ]; then
        echo "ERROR: --dns-only requires --pi1 to be specified" >&2
        print_usage
        exit 1
    fi
    
    if [ "$nsm_only" = true ] && [ -z "$pi2_host" ]; then
        echo "ERROR: --nsm-only requires --pi2 to be specified" >&2
        print_usage
        exit 1
    fi
    
    print_header "Orion Sentinel - Remote Orchestration"
    
    # Check required commands on local machine
    require_cmd ssh
    require_cmd git
    
    # Show configuration
    echo ""
    echo "[INFO] Configuration:"
    if [ -n "$pi1_host" ] && [ "$nsm_only" = false ]; then
        echo "[INFO]   Pi #1 (DNS): $pi1_host"
    fi
    if [ -n "$pi2_host" ] && [ "$dns_only" = false ]; then
        echo "[INFO]   Pi #2 (NSM): $pi2_host"
    fi
    echo ""
    
    # Confirm before proceeding
    if ! confirm "Proceed with installation?"; then
        echo "[INFO] Installation cancelled."
        exit 0
    fi
    
    # Set up DNS Pi if requested
    if [ -n "$pi1_host" ] && [ "$nsm_only" = false ]; then
        setup_dns_pi "$pi1_host"
    fi
    
    # Set up NSM Pi if requested
    if [ -n "$pi2_host" ] && [ "$dns_only" = false ]; then
        setup_nsm_pi "$pi2_host"
    fi
    
    print_header "Installation Complete!"
    echo ""
    echo "[INFO] 🎉 Orion Sentinel has been deployed to your Raspberry Pis!"
    echo ""
    echo "[INFO] Next steps:"
    if [ -n "$pi1_host" ] && [ "$nsm_only" = false ]; then
        echo "[INFO]   1. Configure your router's DNS to point to: $pi1_host"
        echo "[INFO]   2. Access Pi-hole admin: http://$pi1_host/admin"
    fi
    if [ -n "$pi2_host" ] && [ "$dns_only" = false ]; then
        echo "[INFO]   3. Access Grafana dashboard: http://$pi2_host:3000"
        echo "[INFO]   4. Connect $pi2_host to a network mirror/SPAN port for traffic monitoring"
    fi
    echo ""
}

# Run main function
main "$@"
