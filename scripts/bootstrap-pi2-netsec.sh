#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for Raspberry Pi #2 - NetSec (NSM + AI)
# This script sets up the Orion Sentinel NetSec component in SPoG mode
# Can be run locally on the Pi or remotely via SSH

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration (can be overridden via environment variables)
readonly NETSEC_REPO_URL="${NETSEC_REPO_URL:-https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai.git}"
readonly NETSEC_REPO_BRANCH="${NETSEC_REPO_BRANCH:-main}"
readonly NETSEC_REPO_DIR="${NETSEC_REPO_DIR:-/opt/Orion-sentinel-netsec-ai}"

# Parse command line arguments
PI_NETSEC_HOST=""
CORESRV_IP=""
LOCAL_MODE=true

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --host <hostname>      Hostname or IP of Pi #2 (for remote mode)"
    echo "  --coresrv <ip>         IP address of CoreSrv (REQUIRED for SPoG mode)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --coresrv 192.168.1.50                           # Run locally in SPoG mode"
    echo "  $0 --host pi-netsec.local --coresrv 192.168.1.50   # Run remotely in SPoG mode"
    echo ""
    echo "Note: CoreSrv IP is required for proper SPoG configuration"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            PI_NETSEC_HOST="$2"
            LOCAL_MODE=false
            shift 2
            ;;
        --coresrv)
            CORESRV_IP="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$CORESRV_IP" ]; then
    print_error "CoreSrv IP is required for SPoG mode"
    print_usage
    exit 1
fi

# Function to execute commands either locally or remotely
exec_cmd() {
    if [ "$LOCAL_MODE" = true ]; then
        bash -c "$*"
    else
        run_ssh "$PI_NETSEC_HOST" "$@"
    fi
}

# Function to configure .env for SPoG mode
configure_env_spog() {
    local coresrv_ip="$1"
    local env_file="$NETSEC_REPO_DIR/.env"
    
    print_header "Configuring Environment for SPoG Mode"
    
    if [ "$LOCAL_MODE" = true ]; then
        # Local mode
        if [ -f "$env_file.example" ]; then
            print_info "Creating .env from .env.example..."
            cp "$env_file.example" "$env_file"
        fi
        
        if [ -f "$env_file" ]; then
            print_info "Updating .env for SPoG mode..."
            
            # Set Loki URL to point to CoreSrv
            if grep -q "^LOKI_URL=" "$env_file"; then
                sed -i "s|^LOKI_URL=.*|LOKI_URL=http://${coresrv_ip}:3100|" "$env_file"
            else
                echo "LOKI_URL=http://${coresrv_ip}:3100" >> "$env_file"
            fi
            
            # Disable local observability
            if grep -q "^LOCAL_OBSERVABILITY=" "$env_file"; then
                sed -i "s|^LOCAL_OBSERVABILITY=.*|LOCAL_OBSERVABILITY=false|" "$env_file"
            else
                echo "LOCAL_OBSERVABILITY=false" >> "$env_file"
            fi
            
            print_info "SPoG configuration applied:"
            print_info "  LOKI_URL=http://${coresrv_ip}:3100"
            print_info "  LOCAL_OBSERVABILITY=false"
        else
            print_warning "No .env file found - creating one..."
            cat > "$env_file" <<EOF
# NetSec Configuration - SPoG Mode
LOKI_URL=http://${coresrv_ip}:3100
LOCAL_OBSERVABILITY=false

# NSM Interface (adjust as needed)
NSM_INTERFACE=eth0

# Add other required variables as needed
EOF
            print_info "Created basic .env file - you may need to add more variables"
        fi
    else
        # Remote mode
        run_ssh "$PI_NETSEC_HOST" "bash -s" <<REMOTE_SCRIPT
set -euo pipefail

env_file="$env_file"

if [ -f "\${env_file}.example" ]; then
    echo "[INFO] Creating .env from .env.example..."
    cp "\${env_file}.example" "\${env_file}"
fi

if [ -f "\${env_file}" ]; then
    echo "[INFO] Updating .env for SPoG mode..."
    
    # Set Loki URL
    if grep -q "^LOKI_URL=" "\${env_file}"; then
        sed -i "s|^LOKI_URL=.*|LOKI_URL=http://${coresrv_ip}:3100|" "\${env_file}"
    else
        echo "LOKI_URL=http://${coresrv_ip}:3100" >> "\${env_file}"
    fi
    
    # Disable local observability
    if grep -q "^LOCAL_OBSERVABILITY=" "\${env_file}"; then
        sed -i "s|^LOCAL_OBSERVABILITY=.*|LOCAL_OBSERVABILITY=false|" "\${env_file}"
    else
        echo "LOCAL_OBSERVABILITY=false" >> "\${env_file}"
    fi
    
    echo "[INFO] SPoG configuration applied"
else
    echo "[WARN] No .env file found - creating basic config..."
    cat > "\${env_file}" <<EOF
LOKI_URL=http://${coresrv_ip}:3100
LOCAL_OBSERVABILITY=false
NSM_INTERFACE=eth0
EOF
fi
REMOTE_SCRIPT
    fi
}

main() {
    print_header "Orion Sentinel - Pi #2 Bootstrap (NetSec / NSM + AI)"
    
    if [ "$LOCAL_MODE" = true ]; then
        print_info "Running in LOCAL mode (on the Pi itself)"
    else
        print_info "Running in REMOTE mode (target: $PI_NETSEC_HOST)"
    fi
    
    print_info "CoreSrv IP: $CORESRV_IP (SPoG mode enabled)"
    
    echo ""
    print_info "This script will install and configure the NetSec component"
    print_info "in Single Pane of Glass (SPoG) mode, sending all logs to CoreSrv."
    echo ""
    
    # Check required commands locally
    require_cmd git
    require_cmd curl
    if [ "$LOCAL_MODE" = false ]; then
        require_cmd ssh
    fi
    
    # Step 1: Install Docker
    print_header "Step 1: Installing Docker"
    if [ "$LOCAL_MODE" = true ]; then
        ensure_docker_installed
    else
        install_docker_remote "$PI_NETSEC_HOST"
    fi
    
    # Step 2: Clone the NetSec repository
    print_header "Step 2: Cloning NetSec Repository"
    
    if [ "$LOCAL_MODE" = true ]; then
        # Local mode - clone directly
        sudo mkdir -p "$(dirname "$NETSEC_REPO_DIR")"
        
        if [ -d "$NETSEC_REPO_DIR" ]; then
            print_info "Repository exists, updating..."
            sudo git -C "$NETSEC_REPO_DIR" pull || print_warning "Git pull failed, continuing..."
        else
            print_info "Cloning repository to $NETSEC_REPO_DIR..."
            sudo git clone --branch "$NETSEC_REPO_BRANCH" "$NETSEC_REPO_URL" "$NETSEC_REPO_DIR"
        fi
        
        sudo chown -R "$USER:$USER" "$NETSEC_REPO_DIR"
    else
        # Remote mode - clone via SSH
        run_ssh "$PI_NETSEC_HOST" "sudo mkdir -p $(dirname "$NETSEC_REPO_DIR")"
        
        if run_ssh "$PI_NETSEC_HOST" "[ -d $NETSEC_REPO_DIR ]"; then
            print_info "Repository exists on remote host, updating..."
            run_ssh "$PI_NETSEC_HOST" "cd $NETSEC_REPO_DIR && sudo git pull" || print_warning "Git pull failed, continuing..."
        else
            print_info "Cloning repository on remote host..."
            run_ssh "$PI_NETSEC_HOST" "sudo git clone --branch $NETSEC_REPO_BRANCH $NETSEC_REPO_URL $NETSEC_REPO_DIR"
        fi
        
        run_ssh "$PI_NETSEC_HOST" "sudo chown -R \$USER:\$USER $NETSEC_REPO_DIR"
    fi
    
    # Step 3: Configure .env for SPoG mode
    configure_env_spog "$CORESRV_IP"
    
    # Step 4: Bring up NetSec stacks
    print_header "Step 4: Starting NetSec Stacks"
    
    if [ "$LOCAL_MODE" = true ]; then
        # Start NSM stack
        if [ -d "$NETSEC_REPO_DIR/stacks/nsm" ]; then
            print_info "Starting NSM stack..."
            (cd "$NETSEC_REPO_DIR/stacks/nsm" && docker compose -f docker-compose.yml up -d) || print_warning "NSM stack start may have failed"
        else
            print_warning "NSM stack directory not found at $NETSEC_REPO_DIR/stacks/nsm"
        fi
        
        # Start AI stack
        if [ -d "$NETSEC_REPO_DIR/stacks/ai" ]; then
            print_info "Starting AI stack..."
            (cd "$NETSEC_REPO_DIR/stacks/ai" && docker compose up -d) || print_warning "AI stack start may have failed"
        else
            print_warning "AI stack directory not found at $NETSEC_REPO_DIR/stacks/ai"
        fi
        
        # Alternative: single docker-compose.yml in root
        if [ -f "$NETSEC_REPO_DIR/docker-compose.yml" ]; then
            print_info "Starting NetSec stack from root..."
            (cd "$NETSEC_REPO_DIR" && docker compose up -d) || print_warning "Root compose start may have failed"
        fi
    else
        # Remote mode
        if run_ssh "$PI_NETSEC_HOST" "[ -d $NETSEC_REPO_DIR/stacks/nsm ]"; then
            print_info "Starting NSM stack on remote host..."
            run_ssh "$PI_NETSEC_HOST" "cd $NETSEC_REPO_DIR/stacks/nsm && docker compose -f docker-compose.yml up -d" || print_warning "NSM stack start may have failed"
        fi
        
        if run_ssh "$PI_NETSEC_HOST" "[ -d $NETSEC_REPO_DIR/stacks/ai ]"; then
            print_info "Starting AI stack on remote host..."
            run_ssh "$PI_NETSEC_HOST" "cd $NETSEC_REPO_DIR/stacks/ai && docker compose up -d" || print_warning "AI stack start may have failed"
        fi
        
        if run_ssh "$PI_NETSEC_HOST" "[ -f $NETSEC_REPO_DIR/docker-compose.yml ]"; then
            print_info "Starting NetSec stack from root on remote host..."
            run_ssh "$PI_NETSEC_HOST" "cd $NETSEC_REPO_DIR && docker compose up -d" || print_warning "Root compose start may have failed"
        fi
    fi
    
    # Step 5: Verify deployment
    print_header "Step 5: Verifying Deployment"
    
    print_info "Checking running containers..."
    if [ "$LOCAL_MODE" = true ]; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || print_warning "Could not list containers"
    else
        run_ssh "$PI_NETSEC_HOST" "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" || print_warning "Could not list containers"
    fi
    
    # Print completion information
    print_header "Installation Complete!"
    
    local pi_ip
    if [ "$LOCAL_MODE" = true ]; then
        pi_ip=$(get_local_ip)
    else
        pi_ip="$PI_NETSEC_HOST"
    fi
    
    echo ""
    print_info "✅ NetSec component has been set up on Pi #2 in SPoG mode"
    echo ""
    print_info "📋 Configuration Summary:"
    echo ""
    print_info "  Pi IP:       $pi_ip"
    print_info "  CoreSrv IP:  $CORESRV_IP"
    print_info "  Loki URL:    http://$CORESRV_IP:3100"
    print_info "  Mode:        SPoG (logs sent to CoreSrv)"
    echo ""
    print_info "📊 Verification Steps:"
    echo ""
    print_info "1. Check running containers on Pi #2:"
    if [ "$LOCAL_MODE" = true ]; then
        print_info "   docker ps"
    else
        print_info "   ssh $PI_NETSEC_HOST docker ps"
    fi
    echo ""
    print_info "2. Verify logs in Grafana on CoreSrv:"
    print_info "   - Access Grafana at http://$CORESRV_IP:3000"
    print_info "   - Go to Explore → Loki"
    print_info "   - Query: {host=\"pi-netsec\"}"
    print_info "   - You should see logs from NetSec components"
    echo ""
    print_info "3. Check Prometheus targets on CoreSrv (if configured):"
    print_info "   - Access Prometheus at http://$CORESRV_IP:9090/targets"
    print_info "   - Look for pi-netsec exporters"
    echo ""
    print_info "4. Optional: Access local NetSec UI (if exposed):"
    print_info "   - NSM UI:  http://$pi_ip:8081 (if available)"
    print_info "   - AI API:  http://$pi_ip:5000 (if available)"
    echo ""
    print_info "📝 Next Steps:"
    echo ""
    print_info "1. Configure network monitoring interface in $NETSEC_REPO_DIR/.env"
    print_info "2. Set up port mirroring on your network switch"
    print_info "3. Review and customize Suricata rules if needed"
    print_info "4. Configure Grafana dashboards on CoreSrv for NetSec metrics"
    echo ""
    print_info "Documentation:"
    print_info "  Repository: $NETSEC_REPO_DIR"
    print_info "  See README.md for advanced configuration"
    echo ""
    
    print_header "Bootstrap Complete!"
    print_info "Your NetSec Pi is ready and connected to CoreSrv! 🎉"
}

# Run main function
main "$@"
