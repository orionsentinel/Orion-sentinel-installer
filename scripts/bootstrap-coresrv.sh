#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for CoreSrv (Dell) - Central Observability
# This script sets up the Orion Sentinel CoreSrv component (SPoG)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration (can be overridden via environment variables)
readonly CORESRV_REPO_URL="${CORESRV_REPO_URL:-https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv.git}"
readonly CORESRV_REPO_BRANCH="${CORESRV_REPO_BRANCH:-main}"
readonly CORESRV_REPO_DIR="${CORESRV_REPO_DIR:-/opt/Orion-Sentinel-CoreSrv}"
readonly CORESRV_DATA_ROOT="${CORESRV_DATA_ROOT:-/srv/orion-sentinel-core}"

main() {
    print_header "Orion Sentinel - CoreSrv Bootstrap (Dell/SPoG)"
    
    print_info "This script will prepare the CoreSrv (Dell) as the central"
    print_info "Single Pane of Glass (SPoG) for the Orion Sentinel deployment."
    echo ""
    
    # Check required commands
    require_cmd git
    require_cmd curl
    
    # Step 1: Install Docker
    ensure_docker_installed
    
    # Step 2: Create required directory structure
    print_header "Creating Directory Structure"
    
    local directories=(
        "$CORESRV_DATA_ROOT/config"
        "$CORESRV_DATA_ROOT/monitoring"
        "$CORESRV_DATA_ROOT/cloud"
        "$CORESRV_DATA_ROOT/backups"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            print_info "Creating directory: $dir"
            sudo mkdir -p "$dir"
            sudo chown -R "$USER:$USER" "$CORESRV_DATA_ROOT"
        else
            print_info "Directory already exists: $dir"
        fi
    done
    
    # Step 3: Clone the CoreSrv repository
    print_header "Cloning CoreSrv Repository"
    
    if [ -d "$CORESRV_REPO_DIR" ]; then
        print_info "Repository already exists at: $CORESRV_REPO_DIR"
        
        if confirm "Do you want to pull the latest changes?"; then
            print_info "Pulling latest changes..."
            (
                cd "$CORESRV_REPO_DIR" || exit 1
                git pull || print_warning "Could not pull latest changes (you may have local modifications)"
            )
        fi
    else
        print_info "Cloning repository from: $CORESRV_REPO_URL"
        
        # Clone with sudo if needed for /opt directory
        if sudo git clone --branch "$CORESRV_REPO_BRANCH" "$CORESRV_REPO_URL" "$CORESRV_REPO_DIR"; then
            print_info "Repository cloned successfully!"
            sudo chown -R "$USER:$USER" "$CORESRV_REPO_DIR"
        else
            print_error "Failed to clone repository"
            exit 1
        fi
    fi
    
    # Step 4: Check for env files and offer to generate them
    print_header "Environment File Configuration"
    
    cd "$CORESRV_REPO_DIR" || exit 1
    
    # Check if env directory exists
    if [ -d "env" ]; then
        # Check for .env.core
        if [ ! -f "env/.env.core" ] && [ -f "env/.env.core.example" ]; then
            print_info "Creating env/.env.core from example file..."
            cp env/.env.core.example env/.env.core
            print_warning "Please edit env/.env.core and configure:"
            print_warning "  - AUTHELIA_JWT_SECRET"
            print_warning "  - AUTHELIA_SESSION_SECRET"
            print_warning "  - AUTHELIA_STORAGE_ENCRYPTION_KEY"
        else
            print_info "env/.env.core already exists or no example file found"
        fi
        
        # Check for .env.monitoring
        if [ ! -f "env/.env.monitoring" ] && [ -f "env/.env.monitoring.example" ]; then
            print_info "Creating env/.env.monitoring from example file..."
            cp env/.env.monitoring.example env/.env.monitoring
            print_warning "Please edit env/.env.monitoring and configure:"
            print_warning "  - MONITORING_ROOT (default: $CORESRV_DATA_ROOT/monitoring)"
            print_warning "  - GRAFANA_ADMIN_USER"
            print_warning "  - GRAFANA_ADMIN_PASSWORD"
        else
            print_info "env/.env.monitoring already exists or no example file found"
        fi
    else
        print_warning "env directory not found in repository"
        print_info "You may need to configure environment files manually"
    fi
    
    # Step 5: Print completion information
    print_header "CoreSrv Bootstrap Complete!"
    
    echo ""
    print_info "CoreSrv repository location: $CORESRV_REPO_DIR"
    print_info "Data directories created under: $CORESRV_DATA_ROOT"
    echo ""
    print_info "📋 Next Steps:"
    echo ""
    print_info "1. Configure environment files:"
    print_info "   cd $CORESRV_REPO_DIR/env"
    print_info "   - Edit .env.core (Authelia secrets, domain settings)"
    print_info "   - Edit .env.monitoring (Grafana credentials, data paths)"
    echo ""
    print_info "2. Bring up the core stack:"
    print_info "   cd $CORESRV_REPO_DIR"
    print_info "   ./orionctl.sh up-core     # Traefik + Authelia"
    echo ""
    print_info "3. Bring up monitoring stack:"
    print_info "   ./orionctl.sh up-observability  # Prometheus + Loki + Grafana"
    echo ""
    print_info "4. After Pis are configured, bring up full stack:"
    print_info "   ./orionctl.sh up-full"
    echo ""
    print_info "5. Access services:"
    print_info "   - Grafana: https://grafana.local (or your configured domain)"
    print_info "   - Traefik: https://traefik.local"
    echo ""
    print_warning "Remember to configure your local DNS or /etc/hosts to point"
    print_warning "service domains to this CoreSrv IP address"
    echo ""
    
    print_header "Bootstrap Complete!"
    print_info "CoreSrv is ready for configuration! 🎉"
}

# Run main function
main "$@"
