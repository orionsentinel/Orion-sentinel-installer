#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for CoreSrv (Dell Server)
# This script sets up the Orion Sentinel Core Server as the central SPoG

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration (can be overridden via environment variables)
readonly CORESRV_REPO_URL="${CORESRV_REPO_URL:-https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv.git}"
readonly CORESRV_REPO_BRANCH="${CORESRV_REPO_BRANCH:-main}"
readonly CORESRV_REPO_DIR="${CORESRV_REPO_DIR:-/opt/Orion-Sentinel-CoreSrv}"
readonly ORION_DATA_ROOT="${ORION_DATA_ROOT:-/srv/orion-sentinel-core}"

main() {
    print_header "Orion Sentinel - CoreSrv Bootstrap (Central SPoG)"
    
    print_info "This script will set up the Orion Sentinel Core Server"
    print_info "as the central Single Pane of Glass (SPoG) for your homelab."
    echo ""
    print_info "CoreSrv provides:"
    print_info "  - Traefik reverse proxy with SSL"
    print_info "  - Authelia authentication"
    print_info "  - Loki for centralized log aggregation"
    print_info "  - Grafana for visualization"
    print_info "  - Prometheus for metrics collection"
    echo ""
    
    # Check required commands
    require_cmd git
    require_cmd curl
    
    # Step 1: Install Docker
    print_header "Step 1/5: Installing Docker"
    ensure_docker_installed
    
    # Step 2: Clone/Update CoreSrv Repository
    print_header "Step 2/5: Setting Up CoreSrv Repository"
    print_info "Cloning/updating repository to $CORESRV_REPO_DIR..."
    
    # Create parent directory
    sudo mkdir -p "$(dirname "$CORESRV_REPO_DIR")"
    
    # Clone or update with sudo if needed
    if [ -d "$CORESRV_REPO_DIR" ]; then
        print_info "Repository exists, updating..."
        sudo git -C "$CORESRV_REPO_DIR" pull || print_warning "Git pull failed, continuing..."
    else
        print_info "Cloning repository..."
        sudo git clone --branch "$CORESRV_REPO_BRANCH" "$CORESRV_REPO_URL" "$CORESRV_REPO_DIR"
    fi
    
    # Set ownership to current user for easier editing
    sudo chown -R "$USER:$USER" "$CORESRV_REPO_DIR"
    
    # Step 3: Create Directory Structure
    print_header "Step 3/5: Creating Directory Structure"
    print_info "Creating data directories under $ORION_DATA_ROOT..."
    
    sudo mkdir -p "$ORION_DATA_ROOT"/{config,monitoring,cloud,backups}
    sudo chown -R "$USER:$USER" "$ORION_DATA_ROOT"
    
    print_info "Created:"
    print_info "  - $ORION_DATA_ROOT/config     (Traefik & Authelia configs)"
    print_info "  - $ORION_DATA_ROOT/monitoring (Grafana, Prometheus, Loki data)"
    print_info "  - $ORION_DATA_ROOT/cloud      (Nextcloud data)"
    print_info "  - $ORION_DATA_ROOT/backups    (Backup storage)"
    
    # Step 4: Generate Environment Files
    print_header "Step 4/5: Generating Environment Files"
    
    cd "$CORESRV_REPO_DIR" || exit 1
    
    # Check if env directory and example files exist
    if [ -d "env" ]; then
        # Generate env.core if it doesn't exist
        if [ ! -f "env/.env.core" ] && [ -f "env/.env.core.example" ]; then
            print_info "Generating env/.env.core from example..."
            cp env/.env.core.example env/.env.core
            
            # Auto-generate Authelia secrets
            print_info "Auto-generating Authelia secrets..."
            AUTHELIA_JWT_SECRET=$(openssl rand -base64 32)
            AUTHELIA_SESSION_SECRET=$(openssl rand -base64 32)
            AUTHELIA_STORAGE_ENCRYPTION_KEY=$(openssl rand -base64 32)
            
            # Replace placeholders in .env.core if they exist
            if grep -q "AUTHELIA_JWT_SECRET" env/.env.core; then
                sed -i "s|^AUTHELIA_JWT_SECRET=.*|AUTHELIA_JWT_SECRET=${AUTHELIA_JWT_SECRET}|" env/.env.core
                sed -i "s|^AUTHELIA_SESSION_SECRET=.*|AUTHELIA_SESSION_SECRET=${AUTHELIA_SESSION_SECRET}|" env/.env.core
                sed -i "s|^AUTHELIA_STORAGE_ENCRYPTION_KEY=.*|AUTHELIA_STORAGE_ENCRYPTION_KEY=${AUTHELIA_STORAGE_ENCRYPTION_KEY}|" env/.env.core
                print_info "✓ Authelia secrets auto-generated successfully"
            else
                print_warning "Authelia secret placeholders not found in .env.core"
                print_info "Please manually add these secrets to env/.env.core:"
                print_info "  AUTHELIA_JWT_SECRET=${AUTHELIA_JWT_SECRET}"
                print_info "  AUTHELIA_SESSION_SECRET=${AUTHELIA_SESSION_SECRET}"
                print_info "  AUTHELIA_STORAGE_ENCRYPTION_KEY=${AUTHELIA_STORAGE_ENCRYPTION_KEY}"
            fi
        elif [ -f "env/.env.core" ]; then
            print_info "env/.env.core already exists"
        fi
        
        # Generate env.monitoring if it doesn't exist
        if [ ! -f "env/.env.monitoring" ] && [ -f "env/.env.monitoring.example" ]; then
            print_info "Generating env/.env.monitoring from example..."
            cp env/.env.monitoring.example env/.env.monitoring
            
            # Set MONITORING_ROOT automatically
            if grep -q "MONITORING_ROOT" env/.env.monitoring; then
                sed -i "s|^MONITORING_ROOT=.*|MONITORING_ROOT=${ORION_DATA_ROOT}/monitoring|" env/.env.monitoring
                print_info "✓ MONITORING_ROOT set to ${ORION_DATA_ROOT}/monitoring"
            fi
            
            print_warning "Please edit env/.env.monitoring and set:"
            print_warning "  - GRAFANA_ADMIN_USER"
            print_warning "  - GRAFANA_ADMIN_PASSWORD"
        elif [ -f "env/.env.monitoring" ]; then
            print_info "env/.env.monitoring already exists"
        fi
    else
        print_warning "env directory not found in repository"
        print_info "You may need to create environment files manually"
    fi
    
    # Step 5: Optional - Start Services
    print_header "Step 5/5: Service Startup (Optional)"
    
    if [ -f "./orionctl.sh" ]; then
        print_info "Found orionctl.sh script"
        echo ""
        print_info "You can now start the services:"
        print_info "  cd $CORESRV_REPO_DIR"
        print_info "  ./orionctl.sh up-core          # Start Traefik + Authelia"
        print_info "  ./orionctl.sh up-observability # Start Loki + Grafana + Prometheus"
        echo ""
        
        if confirm "Would you like to start the core services now?"; then
            print_info "Starting core services (Traefik + Authelia)..."
            if ./orionctl.sh up-core; then
                print_info "Core services started successfully!"
            else
                print_warning "Failed to start core services. Check the logs."
            fi
            echo ""
            
            if confirm "Would you like to start the observability stack now?"; then
                print_info "Starting observability stack (Loki + Grafana + Prometheus)..."
                if ./orionctl.sh up-observability; then
                    print_info "Observability stack started successfully!"
                else
                    print_warning "Failed to start observability stack. Check the logs."
                fi
            fi
        fi
    else
        print_warning "orionctl.sh not found in repository"
        print_info "You'll need to start services manually"
    fi
    
    # Print completion summary
    print_header "CoreSrv Bootstrap Complete!"
    
    local_ip=$(get_local_ip)
    
    echo ""
    print_info "📋 Summary:"
    echo ""
    print_info "Repository:  $CORESRV_REPO_DIR"
    print_info "Data Root:   $ORION_DATA_ROOT"
    print_info "Server IP:   $local_ip"
    echo ""
    print_info "📝 Next Steps:"
    echo ""
    print_info "1. Edit environment files:"
    print_info "   $CORESRV_REPO_DIR/env/.env.core"
    print_info "   $CORESRV_REPO_DIR/env/.env.monitoring"
    echo ""
    print_info "2. Update MONITORING_ROOT in .env.monitoring:"
    print_info "   MONITORING_ROOT=$ORION_DATA_ROOT/monitoring"
    echo ""
    print_info "3. Generate secrets for Authelia:"
    print_info "   AUTHELIA_JWT_SECRET=\$(openssl rand -base64 32)"
    print_info "   AUTHELIA_SESSION_SECRET=\$(openssl rand -base64 32)"
    print_info "   AUTHELIA_STORAGE_ENCRYPTION_KEY=\$(openssl rand -base64 32)"
    echo ""
    print_info "4. Start services (if not already started):"
    print_info "   cd $CORESRV_REPO_DIR"
    print_info "   ./orionctl.sh up-core"
    print_info "   ./orionctl.sh up-observability"
    echo ""
    print_info "5. Configure DNS or /etc/hosts for Traefik hostnames:"
    print_info "   $local_ip  grafana.local traefik.local auth.local"
    echo ""
    print_info "6. Access services:"
    print_info "   Grafana:  https://grafana.local (or http://$local_ip:3000)"
    print_info "   Traefik:  https://traefik.local"
    print_info "   Loki:     http://$local_ip:3100"
    echo ""
    print_info "7. Bootstrap the Pis using their respective scripts:"
    print_info "   ./scripts/bootstrap-pi1-dns.sh --host <pi-dns-ip> --coresrv $local_ip"
    print_info "   ./scripts/bootstrap-pi2-netsec.sh --host <pi-netsec-ip> --coresrv $local_ip"
    echo ""
    
    print_header "Setup Complete!"
    print_info "Your CoreSrv is ready to act as the central SPoG! 🎉"
}

# Run main function
main "$@"
