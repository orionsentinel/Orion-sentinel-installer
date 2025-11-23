#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for Raspberry Pi #2 - Network Security & Monitoring
# This script sets up the Orion Sentinel NetSec AI component in SPoG mode

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration (can be overridden via environment variables)
readonly PI_NETSEC_HOST="${PI_NETSEC_HOST:-}"
readonly CORESRV_IP="${CORESRV_IP:-}"
readonly NETSEC_REPO_URL="${NETSEC_REPO_URL:-https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai.git}"
readonly NETSEC_REPO_BRANCH="${NETSEC_REPO_BRANCH:-main}"
readonly NETSEC_REPO_DIR="${NETSEC_REPO_DIR:-/opt/Orion-sentinel-netsec-ai}"


main() {
    print_header "Orion Sentinel - Pi #2 Bootstrap (NetSec & AI)"
    
    print_info "This script will install and configure the NetSec & AI component"
    print_info "on Pi #2 in SPoG mode (sending logs to CoreSrv)."
    echo ""
    
    # Determine if running remotely or locally
    local pi_host="${PI_NETSEC_HOST}"
    local coresrv_ip="${CORESRV_IP}"
    local is_remote="false"
    
    # Prompt for parameters if not set
    if [ -z "$pi_host" ]; then
        read -r -p "Enter Pi NetSec hostname or IP address (leave empty for local installation): " pi_host
    fi
    
    if [ -n "$pi_host" ]; then
        is_remote="true"
        print_info "Remote installation mode: $pi_host"
    else
        print_info "Local installation mode"
    fi
    
    if [ -z "$coresrv_ip" ]; then
        read -r -p "Enter CoreSrv IP address for centralized monitoring: " coresrv_ip
    fi
    
    if [ -z "$coresrv_ip" ]; then
        print_error "CoreSrv IP is required for SPoG mode"
        exit 1
    fi
    
    # Check required commands
    require_cmd git
    require_cmd curl
    
    if [ "$is_remote" = "true" ]; then
        require_cmd ssh
    fi
    
    # Step 1: Install Docker
    if [ "$is_remote" = "true" ]; then
        ensure_docker_installed "$pi_host"
    else
        ensure_docker_installed
    fi
    
    # Step 2: Clone or update the NetSec repository
    print_header "Setting Up NetSec Repository"
    
    if [ "$is_remote" = "true" ]; then
        print_info "Setting up NetSec repository on $pi_host..."
        
        # Check if directory exists on remote host
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "[ -d '$NETSEC_REPO_DIR' ]"; then
            print_info "Repository already exists at: $NETSEC_REPO_DIR"
            
            if confirm "Do you want to pull the latest changes?"; then
                print_info "Pulling latest changes..."
                ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "cd '$NETSEC_REPO_DIR' && git pull" || \
                    print_warning "Could not pull latest changes (you may have local modifications)"
            fi
        else
            print_info "Cloning repository from: $NETSEC_REPO_URL"
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" \
                "sudo mkdir -p '$NETSEC_REPO_DIR' && sudo chown -R \$USER:\$USER /opt && \
                 git clone --branch '$NETSEC_REPO_BRANCH' '$NETSEC_REPO_URL' '$NETSEC_REPO_DIR'"
        fi
    else
        # Local installation
        clone_repo_if_missing "$NETSEC_REPO_URL" "$NETSEC_REPO_DIR" "$NETSEC_REPO_BRANCH"
    fi
    
    # Step 3: Generate or update .env file for SPoG mode
    print_header "Configuring NetSec Stack for SPoG Mode"
    
    local env_config="LOKI_URL=http://${coresrv_ip}:3100
LOCAL_OBSERVABILITY=false"
    
    if [ "$is_remote" = "true" ]; then
        print_info "Configuring .env file on $pi_host for SPoG mode..."
        
        # Check if .env exists, if not create from example if available
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" bash <<EOFREMOTE
set -euo pipefail
cd '$NETSEC_REPO_DIR'

if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
fi

# Update or append SPoG configuration
if [ -f .env ]; then
    # Remove old LOKI_URL and LOCAL_OBSERVABILITY if they exist
    sed -i '/^LOKI_URL=/d' .env
    sed -i '/^LOCAL_OBSERVABILITY=/d' .env
    
    # Append new configuration
    cat >> .env <<EOFENV
$env_config
EOFENV
    
    echo ".env file updated for SPoG mode"
else
    # Create new .env file
    cat > .env <<EOFENV
$env_config
EOFENV
    echo ".env file created for SPoG mode"
fi
EOFREMOTE
    else
        print_info "Configuring .env file for SPoG mode..."
        
        cd "$NETSEC_REPO_DIR" || exit 1
        
        if [ ! -f .env ] && [ -f .env.example ]; then
            cp .env.example .env
        fi
        
        if [ -f .env ]; then
            # Remove old LOKI_URL and LOCAL_OBSERVABILITY if they exist
            sed -i '/^LOKI_URL=/d' .env
            sed -i '/^LOCAL_OBSERVABILITY=/d' .env
            
            # Append new configuration
            echo "$env_config" >> .env
            
            print_info ".env file updated for SPoG mode"
        else
            # Create new .env file
            echo "$env_config" > .env
            print_info ".env file created for SPoG mode"
        fi
    fi
    
    print_info "SPoG configuration:"
    print_info "  LOKI_URL=http://${coresrv_ip}:3100"
    print_info "  LOCAL_OBSERVABILITY=false"
    
    # Step 4: Bring up the NetSec stack in SPoG mode
    print_header "Starting NetSec Stack"
    
    if [ "$is_remote" = "true" ]; then
        print_info "Starting NetSec stack on $pi_host..."
        
        # Bring up NSM stack
        print_info "Starting NSM stack..."
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" \
            "cd '$NETSEC_REPO_DIR/stacks/nsm' && docker compose -f docker-compose.yml up -d" || \
            print_warning "NSM stack may not have started - check repo structure"
        
        # Bring up AI stack
        print_info "Starting AI stack..."
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" \
            "cd '$NETSEC_REPO_DIR/stacks/ai' && docker compose up -d" || \
            print_warning "AI stack may not have started - check repo structure"
        
        print_info "NetSec stacks started!"
    else
        # Bring up NSM stack locally
        if [ -d "$NETSEC_REPO_DIR/stacks/nsm" ]; then
            print_info "Starting NSM stack..."
            (cd "$NETSEC_REPO_DIR/stacks/nsm" && docker compose -f docker-compose.yml up -d)
        else
            print_warning "NSM stack directory not found - check repo structure"
        fi
        
        # Bring up AI stack locally
        if [ -d "$NETSEC_REPO_DIR/stacks/ai" ]; then
            print_info "Starting AI stack..."
            (cd "$NETSEC_REPO_DIR/stacks/ai" && docker compose up -d)
        else
            print_warning "AI stack directory not found - check repo structure"
        fi
        
        print_info "NetSec stacks started!"
    fi
    
    # Step 5: Print completion information
    print_header "Installation Complete!"
    
    local pi_display_name="${pi_host:-localhost}"
    
    echo ""
    print_info "NetSec & AI component has been set up on Pi #2 ($pi_display_name)"
    print_info "Running in SPoG mode - logs forwarding to CoreSrv at $coresrv_ip"
    echo ""
    print_info "📋 Summary:"
    echo ""
    
    if [ "$is_remote" = "true" ]; then
        print_info "NetSec containers running on $pi_host:"
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" || \
            print_warning "Could not retrieve container status"
    else
        print_info "NetSec containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || \
            print_warning "Could not retrieve container status"
    fi
    
    echo ""
    print_info "📋 Next Steps:"
    echo ""
    print_info "1. Check Loki on CoreSrv:"
    print_info "   - Navigate to Loki Explore in Grafana on CoreSrv"
    print_info "   - Filter logs with: {host=\"pi-netsec\"}"
    print_info "   - Verify NetSec container logs are appearing"
    echo ""
    print_info "2. Monitor NetSec health:"
    print_info "   - Check if NetSec services are responding"
    print_info "   - Verify network traffic is being captured (if port mirroring configured)"
    echo ""
    print_info "3. Access services (if exposed):"
    print_info "   - NetSec web UI or API may be available on the Pi"
    print_info "   - Check the repository documentation for details"
    echo ""
    
    print_header "Bootstrap Complete!"
    print_info "Your NetSec Pi is ready and connected to CoreSrv! 🎉"
}

# Run main function
main "$@"
