#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for Raspberry Pi #1 - DNS & Privacy
# This script sets up the Orion Sentinel DNS HA component and connects it to CoreSrv

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration (can be overridden via environment variables)
readonly PI_DNS_HOST="${PI_DNS_HOST:-}"
readonly CORESRV_IP="${CORESRV_IP:-}"
readonly DNS_REPO_URL="${DNS_REPO_URL:-https://github.com/yorgosroussakis/rpi-ha-dns-stack.git}"
readonly DNS_REPO_BRANCH="${DNS_REPO_BRANCH:-main}"
readonly DNS_REPO_DIR="${DNS_REPO_DIR:-/opt/rpi-ha-dns-stack}"
readonly PROMTAIL_VERSION="${PROMTAIL_VERSION:-2.9.3}"


# Deploy Promtail agent for log forwarding to CoreSrv
deploy_promtail() {
    local pi_host="$1"
    local coresrv_ip="$2"
    local is_remote="$3"
    
    print_header "Deploying Promtail Agent"
    
    local promtail_config_content=$(cat <<EOFCONFIG
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
      - docker: {}
EOFCONFIG
)
    
    if [ "$is_remote" = "true" ]; then
        print_info "Deploying Promtail on remote host: $pi_host"
        
        # Create Promtail config directory and file on remote host
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "sudo mkdir -p /etc/promtail"
        echo "$promtail_config_content" | ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "sudo tee /etc/promtail/promtail-config.yml > /dev/null"
        
        # Deploy Promtail container on remote host
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" bash <<'EOFREMOTE'
set -euo pipefail

# Stop and remove existing Promtail container if it exists
if docker ps -a --format '{{.Names}}' | grep -q '^promtail$'; then
    echo "Stopping and removing existing Promtail container..."
    docker stop promtail || true
    docker rm promtail || true
fi

# Start Promtail container
echo "Starting Promtail container..."
docker run -d \
    --name promtail \
    --restart unless-stopped \
    -v /etc/promtail/promtail-config.yml:/etc/promtail/config.yml:ro \
    -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    grafana/promtail:2.9.3 \
    -config.file=/etc/promtail/config.yml

echo "Promtail deployed successfully!"
EOFREMOTE
        
        print_info "Promtail agent deployed on $pi_host"
    else
        print_info "Deploying Promtail locally"
        
        # Create Promtail config directory and file locally
        sudo mkdir -p /etc/promtail
        echo "$promtail_config_content" | sudo tee /etc/promtail/promtail-config.yml > /dev/null
        
        # Stop and remove existing Promtail container if it exists
        if docker ps -a --format '{{.Names}}' | grep -q '^promtail$'; then
            print_info "Stopping and removing existing Promtail container..."
            docker stop promtail || true
            docker rm promtail || true
        fi
        
        # Start Promtail container
        print_info "Starting Promtail container..."
        docker run -d \
            --name promtail \
            --restart unless-stopped \
            -v /etc/promtail/promtail-config.yml:/etc/promtail/config.yml:ro \
            -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            "grafana/promtail:${PROMTAIL_VERSION}" \
            -config.file=/etc/promtail/config.yml
        
        print_info "Promtail agent deployed successfully!"
    fi
}

main() {
    print_header "Orion Sentinel - Pi #1 Bootstrap (DNS & Privacy)"
    
    print_info "This script will install and configure the DNS & Privacy component"
    print_info "on Pi #1 and connect it to CoreSrv for centralized monitoring."
    echo ""
    
    # Determine if running remotely or locally
    local pi_host="${PI_DNS_HOST}"
    local coresrv_ip="${CORESRV_IP}"
    local is_remote="false"
    
    # Prompt for parameters if not set
    if [ -z "$pi_host" ]; then
        read -r -p "Enter Pi DNS hostname or IP address (leave empty for local installation): " pi_host
    fi
    
    if [ -n "$pi_host" ]; then
        is_remote="true"
        print_info "Remote installation mode: $pi_host"
    else
        print_info "Local installation mode"
    fi
    
    if [ -z "$coresrv_ip" ]; then
        read -r -p "Enter CoreSrv IP address for centralized logging: " coresrv_ip
    fi
    
    if [ -z "$coresrv_ip" ]; then
        print_warning "CoreSrv IP not provided - Promtail will not be deployed"
        print_warning "You can deploy it later by re-running this script with CORESRV_IP set"
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
    
    # Step 2: Clone or update the DNS repository
    print_header "Setting Up DNS Repository"
    
    if [ "$is_remote" = "true" ]; then
        print_info "Setting up DNS repository on $pi_host..."
        
        # Check if directory exists on remote host
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "[ -d '$DNS_REPO_DIR' ]"; then
            print_info "Repository already exists at: $DNS_REPO_DIR"
            
            if confirm "Do you want to pull the latest changes?"; then
                print_info "Pulling latest changes..."
                ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "cd '$DNS_REPO_DIR' && git pull" || \
                    print_warning "Could not pull latest changes (you may have local modifications)"
            fi
        else
            print_info "Cloning repository from: $DNS_REPO_URL"
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" \
                "sudo mkdir -p '$DNS_REPO_DIR' && sudo chown -R \$USER:\$USER /opt && \
                 git clone --branch '$DNS_REPO_BRANCH' '$DNS_REPO_URL' '$DNS_REPO_DIR'"
        fi
    else
        # Local installation
        clone_repo_if_missing "$DNS_REPO_URL" "$DNS_REPO_DIR" "$DNS_REPO_BRANCH"
    fi
    
    # Step 3: Configure .env file with CoreSrv integration if needed
    print_header "Configuring DNS Stack"
    
    if [ "$is_remote" = "true" ]; then
        print_info "Configuration should be done on the Pi itself or via the DNS repo's install script"
        print_info "Typical .env values to configure:"
        print_info "  - Pi LAN IP address"
        print_info "  - Virtual IP (VIP) for HA if using multiple DNS Pis"
        print_info "  - Keepalived settings for HA"
    else
        print_info "Please configure the .env file in: $DNS_REPO_DIR"
        print_info "You may need to set Pi IP, VIP, and other DNS-specific settings"
    fi
    
    # Step 4: Bring up the DNS stack
    print_header "Starting DNS Stack"
    
    if [ "$is_remote" = "true" ]; then
        print_info "Starting DNS stack on $pi_host..."
        
        # Check if docker-compose.yml exists and bring up the stack
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "[ -f '$DNS_REPO_DIR/docker-compose.yml' ]"; then
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" \
                "cd '$DNS_REPO_DIR' && docker compose up -d"
            print_info "DNS stack started successfully!"
        else
            print_warning "docker-compose.yml not found in $DNS_REPO_DIR"
            print_info "Please start the stack manually or check the repository structure"
        fi
    else
        if [ -f "$DNS_REPO_DIR/docker-compose.yml" ]; then
            print_info "Starting DNS stack..."
            (cd "$DNS_REPO_DIR" && docker compose up -d)
            print_info "DNS stack started successfully!"
        else
            print_warning "docker-compose.yml not found in $DNS_REPO_DIR"
            print_info "Please start the stack manually or check the repository structure"
        fi
    fi
    
    # Step 5: Deploy Promtail if CoreSrv IP is provided
    if [ -n "$coresrv_ip" ]; then
        deploy_promtail "${pi_host:-localhost}" "$coresrv_ip" "$is_remote"
    fi
    
    # Step 6: Print completion information
    print_header "Installation Complete!"
    
    local pi_display_name="${pi_host:-localhost}"
    
    echo ""
    print_info "DNS & Privacy component has been set up on Pi #1 ($pi_display_name)"
    echo ""
    print_info "📋 Summary:"
    echo ""
    
    if [ "$is_remote" = "true" ]; then
        print_info "DNS stack containers running on $pi_host:"
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "docker ps --filter name=pihole --filter name=unbound --format 'table {{.Names}}\t{{.Status}}'" || \
            print_warning "Could not retrieve container status"
        
        if [ -n "$coresrv_ip" ]; then
            echo ""
            print_info "Promtail running on $pi_host:"
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$pi_host" "docker ps --filter name=promtail --format 'table {{.Names}}\t{{.Status}}'" || \
                print_warning "Could not retrieve Promtail status"
        fi
    else
        print_info "DNS stack containers:"
        docker ps --filter name=pihole --filter name=unbound --format "table {{.Names}}\t{{.Status}}" || \
            print_warning "Could not retrieve container status"
        
        if [ -n "$coresrv_ip" ]; then
            echo ""
            print_info "Promtail status:"
            docker ps --filter name=promtail --format "table {{.Names}}\t{{.Status}}" || \
                print_warning "Could not retrieve Promtail status"
        fi
    fi
    
    echo ""
    print_info "📋 Next Steps:"
    echo ""
    
    if [ -n "$coresrv_ip" ]; then
        print_info "1. Check Grafana on CoreSrv:"
        print_info "   - Navigate to Loki Explore in Grafana"
        print_info "   - Filter logs with: {host=\"pi-dns\"}"
        print_info "   - Verify DNS container logs are appearing"
        echo ""
    fi
    
    print_info "2. Access Pi-hole Admin Interface:"
    print_info "   URL: http://$pi_display_name/admin"
    print_info "   (Check the .env file in $DNS_REPO_DIR for admin password)"
    echo ""
    
    print_info "3. Configure your router:"
    print_info "   Set DNS server to: $pi_display_name"
    print_info "   (Or use the VIP if you configured HA mode)"
    echo ""
    
    print_header "Bootstrap Complete!"
    print_info "Your DNS Pi is ready and connected to CoreSrv! 🎉"
}

# Run main function
main "$@"
