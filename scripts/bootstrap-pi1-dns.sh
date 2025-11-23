#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for Raspberry Pi #1 - DNS & Privacy
# This script sets up the Orion Sentinel DNS HA component
# Can be run locally on the Pi or remotely via SSH

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration (can be overridden via environment variables)
readonly DNS_REPO_URL="${DNS_REPO_URL:-https://github.com/yorgosroussakis/rpi-ha-dns-stack.git}"
readonly DNS_REPO_BRANCH="${DNS_REPO_BRANCH:-main}"
readonly DNS_REPO_DIR="${DNS_REPO_DIR:-/opt/rpi-ha-dns-stack}"

# Parse command line arguments
PI_DNS_HOST=""
CORESRV_IP=""
LOCAL_MODE=true

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --host <hostname>      Hostname or IP of Pi #1 (for remote mode)"
    echo "  --coresrv <ip>         IP address of CoreSrv (for Promtail logging)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run locally on the Pi"
    echo "  $0 --coresrv 192.168.1.50            # Run locally with CoreSrv logging"
    echo "  $0 --host pi-dns.local --coresrv 192.168.1.50  # Run remotely"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            PI_DNS_HOST="$2"
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


# Function to execute commands either locally or remotely
exec_cmd() {
    if [ "$LOCAL_MODE" = true ]; then
        bash -c "$*"
    else
        run_ssh "$PI_DNS_HOST" "$@"
    fi
}

# Function to deploy Promtail configuration for CoreSrv logging
deploy_promtail() {
    local coresrv_ip="$1"
    
    print_header "Deploying Promtail for CoreSrv Logging"
    
    # Create Promtail config
    local promtail_config
    promtail_config=$(cat <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${coresrv_ip}:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: pi-dns
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - labels:
          stream:
      - output:
          source: output
EOF
)
    
    print_info "Creating Promtail configuration..."
    
    if [ "$LOCAL_MODE" = true ]; then
        # Local mode
        mkdir -p /opt/promtail
        echo "$promtail_config" > /opt/promtail/promtail-config.yml
        
        print_info "Starting Promtail container..."
        docker run -d \
            --name promtail \
            --restart unless-stopped \
            -v /opt/promtail/promtail-config.yml:/etc/promtail/config.yml:ro \
            -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            grafana/promtail:latest \
            -config.file=/etc/promtail/config.yml || print_warning "Promtail may already be running"
    else
        # Remote mode
        run_ssh "$PI_DNS_HOST" "mkdir -p /opt/promtail"
        run_ssh "$PI_DNS_HOST" "cat > /opt/promtail/promtail-config.yml" <<EOF
$promtail_config
EOF
        
        print_info "Starting Promtail container on remote host..."
        run_ssh "$PI_DNS_HOST" "docker run -d \
            --name promtail \
            --restart unless-stopped \
            -v /opt/promtail/promtail-config.yml:/etc/promtail/config.yml:ro \
            -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            grafana/promtail:latest \
            -config.file=/etc/promtail/config.yml" || print_warning "Promtail may already be running"
    fi
    
    print_info "Promtail deployed successfully!"
    print_info "Logs will be sent to Loki at http://${coresrv_ip}:3100"
}

main() {
    print_header "Orion Sentinel - Pi #1 Bootstrap (DNS & Privacy)"
    
    if [ "$LOCAL_MODE" = true ]; then
        print_info "Running in LOCAL mode (on the Pi itself)"
    else
        print_info "Running in REMOTE mode (target: $PI_DNS_HOST)"
    fi
    
    if [ -n "$CORESRV_IP" ]; then
        print_info "CoreSrv integration enabled (CoreSrv IP: $CORESRV_IP)"
    fi
    
    echo ""
    print_info "This script will install and configure the DNS & Privacy component"
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
        install_docker_remote "$PI_DNS_HOST"
    fi
    
    # Step 2: Clone the DNS repository
    print_header "Step 2: Cloning DNS Repository"
    
    if [ "$LOCAL_MODE" = true ]; then
        # Local mode - clone directly
        sudo mkdir -p "$(dirname "$DNS_REPO_DIR")"
        
        if [ -d "$DNS_REPO_DIR" ]; then
            print_info "Repository exists, updating..."
            sudo git -C "$DNS_REPO_DIR" pull || print_warning "Git pull failed, continuing..."
        else
            print_info "Cloning repository to $DNS_REPO_DIR..."
            sudo git clone --branch "$DNS_REPO_BRANCH" "$DNS_REPO_URL" "$DNS_REPO_DIR"
        fi
        
        sudo chown -R "$USER:$USER" "$DNS_REPO_DIR"
    else
        # Remote mode - clone via SSH
        run_ssh "$PI_DNS_HOST" "sudo mkdir -p $(dirname "$DNS_REPO_DIR")"
        
        if run_ssh "$PI_DNS_HOST" "[ -d $DNS_REPO_DIR ]"; then
            print_info "Repository exists on remote host, updating..."
            run_ssh "$PI_DNS_HOST" "cd $DNS_REPO_DIR && sudo git pull" || print_warning "Git pull failed, continuing..."
        else
            print_info "Cloning repository on remote host..."
            run_ssh "$PI_DNS_HOST" "sudo git clone --branch $DNS_REPO_BRANCH $DNS_REPO_URL $DNS_REPO_DIR"
        fi
        
        run_ssh "$PI_DNS_HOST" "sudo chown -R \$USER:\$USER $DNS_REPO_DIR"
    fi
    
    # Step 3: Generate .env file if needed
    print_header "Step 3: Configuring Environment"
    
    print_info "Checking for .env file in DNS repository..."
    
    if [ "$LOCAL_MODE" = true ]; then
        if [ -f "$DNS_REPO_DIR/.env" ]; then
            print_info ".env file already exists"
        elif [ -f "$DNS_REPO_DIR/.env.example" ]; then
            print_info "Creating .env from .env.example..."
            cp "$DNS_REPO_DIR/.env.example" "$DNS_REPO_DIR/.env"
            print_warning "Please edit $DNS_REPO_DIR/.env to configure:"
            print_warning "  - Pi LAN IP"
            print_warning "  - Virtual IP (if using HA)"
            print_warning "  - Pi-hole password"
        else
            print_warning "No .env.example found - manual configuration may be required"
        fi
    else
        if run_ssh "$PI_DNS_HOST" "[ -f $DNS_REPO_DIR/.env ]"; then
            print_info ".env file already exists on remote host"
        elif run_ssh "$PI_DNS_HOST" "[ -f $DNS_REPO_DIR/.env.example ]"; then
            print_info "Creating .env from .env.example on remote host..."
            run_ssh "$PI_DNS_HOST" "cp $DNS_REPO_DIR/.env.example $DNS_REPO_DIR/.env"
            print_warning "Please SSH to $PI_DNS_HOST and edit $DNS_REPO_DIR/.env"
        else
            print_warning "No .env.example found on remote host"
        fi
    fi
    
    # Step 4: Run the DNS install script
    print_header "Step 4: Running DNS Installation"
    
    if [ "$LOCAL_MODE" = true ]; then
        if [ -f "$DNS_REPO_DIR/scripts/install.sh" ]; then
            print_info "Running DNS install script..."
            (cd "$DNS_REPO_DIR" && bash scripts/install.sh) || print_warning "Install script failed or not found"
        elif [ -f "$DNS_REPO_DIR/docker-compose.yml" ]; then
            print_info "Starting DNS stack with docker compose..."
            (cd "$DNS_REPO_DIR" && docker compose up -d) || print_warning "Docker compose failed"
        else
            print_warning "No install script or docker-compose.yml found"
            print_info "Manual installation required in $DNS_REPO_DIR"
        fi
    else
        if run_ssh "$PI_DNS_HOST" "[ -f $DNS_REPO_DIR/scripts/install.sh ]"; then
            print_info "Running DNS install script on remote host..."
            run_ssh "$PI_DNS_HOST" "cd $DNS_REPO_DIR && bash scripts/install.sh" || print_warning "Install script failed"
        elif run_ssh "$PI_DNS_HOST" "[ -f $DNS_REPO_DIR/docker-compose.yml ]"; then
            print_info "Starting DNS stack on remote host..."
            run_ssh "$PI_DNS_HOST" "cd $DNS_REPO_DIR && docker compose up -d" || print_warning "Docker compose failed"
        else
            print_warning "No install script or docker-compose.yml found on remote host"
        fi
    fi
    
    # Step 5: Deploy Promtail if CoreSrv IP is provided
    if [ -n "$CORESRV_IP" ]; then
        deploy_promtail "$CORESRV_IP"
    fi
    
    # Step 6: Print completion information
    print_header "Installation Complete!"
    
    local pi_ip
    if [ "$LOCAL_MODE" = true ]; then
        pi_ip=$(get_local_ip)
    else
        pi_ip="$PI_DNS_HOST"
    fi
    
    echo ""
    print_info "✅ DNS & Privacy component has been set up on Pi #1"
    echo ""
    print_info "📋 Next Steps:"
    echo ""
    print_info "1. Pi-hole Admin Interface:"
    print_info "   URL: http://$pi_ip/admin"
    print_info "   (Check the .env file in $DNS_REPO_DIR for the admin password)"
    echo ""
    print_info "2. Configure your router:"
    print_info "   Set DNS server to: $pi_ip"
    print_info "   (Or use the VIP if you configured HA mode)"
    echo ""
    
    if [ -n "$CORESRV_IP" ]; then
        print_info "3. Verify logs in Grafana on CoreSrv:"
        print_info "   - Access Grafana at http://$CORESRV_IP:3000"
        print_info "   - Go to Explore → Loki"
        print_info "   - Query: {host=\"pi-dns\"}"
        print_info "   - You should see Docker container logs from this Pi"
        echo ""
        print_info "4. Check Promtail status:"
        if [ "$LOCAL_MODE" = true ]; then
            print_info "   docker logs promtail"
        else
            print_info "   ssh $PI_DNS_HOST docker logs promtail"
        fi
        echo ""
    fi
    
    print_info "For High Availability setup:"
    print_info "  - Edit the .env file in: $DNS_REPO_DIR"
    print_info "  - Configure KEEPALIVED_VIRTUAL_IP and other HA settings"
    print_info "  - Re-run the install script or restart services"
    echo ""
    print_info "Documentation:"
    print_info "  See $DNS_REPO_DIR/README.md for more details"
    echo ""
    
    print_header "Bootstrap Complete!"
    print_info "Your DNS & Privacy Pi is ready! 🎉"
}

# Run main function
main "$@"
