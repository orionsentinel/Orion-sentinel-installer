#!/usr/bin/env bash
set -euo pipefail

# Full orchestration script for deploying Orion Sentinel three-node architecture
# This script coordinates the deployment of CoreSrv + 2 Raspberry Pis

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Global variables
CORESRV_IP=""
PI_DNS_HOST=""
PI_NETSEC_HOST=""
SKIP_CORESRV=false

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Full orchestration script for Orion Sentinel three-node deployment"
    echo ""
    echo "Options:"
    echo "  --coresrv <ip>         IP address of CoreSrv (Dell server)"
    echo "  --pi-dns <host>        Hostname or IP of Pi #1 (DNS)"
    echo "  --pi-netsec <host>     Hostname or IP of Pi #2 (NetSec)"
    echo "  --skip-coresrv         Skip CoreSrv setup (assume already configured)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --coresrv 192.168.1.50 --pi-dns pi1.local --pi-netsec pi2.local"
    echo "  $0 --coresrv 192.168.1.50 --pi-dns 192.168.1.10 --pi-netsec 192.168.1.11"
    echo "  $0 --skip-coresrv --coresrv 192.168.1.50 --pi-dns pi1.local --pi-netsec pi2.local"
    echo ""
    echo "Note: This script requires SSH access to the Pis. CoreSrv setup can be"
    echo "      run manually beforehand using bootstrap-coresrv.sh"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --coresrv)
            CORESRV_IP="$2"
            shift 2
            ;;
        --pi-dns)
            PI_DNS_HOST="$2"
            shift 2
            ;;
        --pi-netsec)
            PI_NETSEC_HOST="$2"
            shift 2
            ;;
        --skip-coresrv)
            SKIP_CORESRV=true
            shift
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
    print_error "CoreSrv IP is required (--coresrv)"
    print_usage
    exit 1
fi

if [ -z "$PI_DNS_HOST" ]; then
    print_error "Pi DNS host is required (--pi-dns)"
    print_usage
    exit 1
fi

if [ -z "$PI_NETSEC_HOST" ]; then
    print_error "Pi NetSec host is required (--pi-netsec)"
    print_usage
    exit 1
fi

main() {
    print_header "Orion Sentinel - Full Stack Deployment"
    
    echo ""
    print_info "🏗️  Three-Node Architecture Deployment"
    echo ""
    print_info "Configuration:"
    print_info "  CoreSrv (SPoG):  $CORESRV_IP"
    print_info "  Pi #1 (DNS):     $PI_DNS_HOST"
    print_info "  Pi #2 (NetSec):  $PI_NETSEC_HOST"
    echo ""
    
    if [ "$SKIP_CORESRV" = true ]; then
        print_warning "Skipping CoreSrv setup (--skip-coresrv specified)"
        print_info "Assuming CoreSrv is already configured at $CORESRV_IP"
    fi
    
    echo ""
    
    # Confirmation
    if ! confirm "Proceed with full deployment?"; then
        print_info "Deployment cancelled."
        exit 0
    fi
    
    # Check required commands
    require_cmd ssh
    require_cmd git
    require_cmd curl
    
    # Step 1: CoreSrv Setup (optional)
    if [ "$SKIP_CORESRV" = false ]; then
        print_header "Step 1/3: Setting up CoreSrv"
        
        print_info "CoreSrv must be set up on the Dell server itself."
        echo ""
        print_info "Please run the following on your CoreSrv ($CORESRV_IP):"
        echo ""
        print_info "  git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git"
        print_info "  cd Orion-sentinel-installer"
        print_info "  ./scripts/bootstrap-coresrv.sh"
        echo ""
        
        if ! confirm "Have you completed CoreSrv setup?"; then
            print_warning "Please set up CoreSrv first, then re-run this script with --skip-coresrv"
            exit 0
        fi
    else
        print_header "Step 1/3: CoreSrv Setup (Skipped)"
        print_info "Assuming CoreSrv is already configured"
    fi
    
    # Step 2: Pi #1 DNS Setup
    print_header "Step 2/3: Setting up Pi #1 (DNS)"
    
    print_info "Deploying DNS stack to $PI_DNS_HOST with CoreSrv integration..."
    echo ""
    
    if [ -f "$SCRIPT_DIR/bootstrap-pi1-dns.sh" ]; then
        bash "$SCRIPT_DIR/bootstrap-pi1-dns.sh" --host "$PI_DNS_HOST" --coresrv "$CORESRV_IP"
    else
        print_error "bootstrap-pi1-dns.sh not found in $SCRIPT_DIR"
        exit 1
    fi
    
    echo ""
    print_info "✅ Pi #1 (DNS) deployment complete"
    echo ""
    
    # Step 3: Pi #2 NetSec Setup
    print_header "Step 3/3: Setting up Pi #2 (NetSec)"
    
    print_info "Deploying NetSec stack to $PI_NETSEC_HOST in SPoG mode..."
    echo ""
    
    if [ -f "$SCRIPT_DIR/bootstrap-pi2-netsec.sh" ]; then
        bash "$SCRIPT_DIR/bootstrap-pi2-netsec.sh" --host "$PI_NETSEC_HOST" --coresrv "$CORESRV_IP"
    else
        print_error "bootstrap-pi2-netsec.sh not found in $SCRIPT_DIR"
        exit 1
    fi
    
    echo ""
    print_info "✅ Pi #2 (NetSec) deployment complete"
    echo ""
    
    # Final Summary
    print_header "🎉 Deployment Complete!"
    
    echo ""
    print_info "Your Orion Sentinel three-node architecture is now deployed!"
    echo ""
    print_info "┌─────────────────────────────────────────────────────────────┐"
    print_info "│                   Deployment Summary                        │"
    print_info "├─────────────────────────────────────────────────────────────┤"
    print_info "│ CoreSrv (SPoG):   $CORESRV_IP                               "
    print_info "│ Pi #1 (DNS):      $PI_DNS_HOST                              "
    print_info "│ Pi #2 (NetSec):   $PI_NETSEC_HOST                           "
    print_info "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    print_info "📋 Post-Deployment Checklist:"
    echo ""
    print_info "1. ✓ CoreSrv is running Loki, Grafana, Prometheus, and Traefik"
    print_info "2. ✓ Pi #1 is running Pi-hole + Unbound + Promtail"
    print_info "3. ✓ Pi #2 is running NSM + AI in SPoG mode"
    echo ""
    
    print_info "🔍 Verification Steps:"
    echo ""
    print_info "1. Access Grafana on CoreSrv:"
    print_info "   URL: https://grafana.local (or http://$CORESRV_IP:3000)"
    print_info "   Default credentials: admin/admin (change on first login)"
    echo ""
    print_info "2. Verify Loki logs in Grafana:"
    print_info "   - Go to Explore → Loki"
    print_info "   - Query for Pi DNS logs:    {host=\"pi-dns\"}"
    print_info "   - Query for Pi NetSec logs: {host=\"pi-netsec\"}"
    echo ""
    print_info "3. Check Prometheus targets (if configured):"
    print_info "   URL: http://$CORESRV_IP:9090/targets"
    print_info "   Look for pi-dns and pi-netsec exporters"
    echo ""
    print_info "4. Test DNS filtering:"
    print_info "   - Configure your router to use $PI_DNS_HOST as DNS server"
    print_info "   - Or manually set DNS to $PI_DNS_HOST on a test device"
    print_info "   - Browse the web and verify ad blocking works"
    print_info "   - Check Pi-hole admin: http://$PI_DNS_HOST/admin"
    echo ""
    print_info "5. Verify NetSec monitoring:"
    print_info "   - Ensure Pi #2 is connected to a mirrored/SPAN port"
    print_info "   - Check for network traffic in Grafana dashboards"
    print_info "   - Review Suricata alerts and AI detections"
    echo ""
    
    print_info "🔧 Optional Configuration:"
    echo ""
    print_info "1. Set up Traefik dynamic configs on CoreSrv:"
    print_info "   - Add routes for https://dns.local → $PI_DNS_HOST"
    print_info "   - Add routes for https://security.local → $PI_NETSEC_HOST"
    echo ""
    print_info "2. Configure High Availability for DNS:"
    print_info "   - Edit .env on Pi #1: /opt/rpi-ha-dns-stack/.env"
    print_info "   - Set up a second Pi with the same script"
    print_info "   - Configure Keepalived for VIP failover"
    echo ""
    print_info "3. Customize alerting:"
    print_info "   - Set up Grafana alerts for critical events"
    print_info "   - Configure notification channels (email, Slack, etc.)"
    echo ""
    print_info "4. Add DNS records or /etc/hosts entries:"
    print_info "   - On your workstation, add to /etc/hosts:"
    print_info "     $CORESRV_IP  grafana.local traefik.local auth.local"
    print_info "     $PI_DNS_HOST  dns.local"
    print_info "     $PI_NETSEC_HOST  security.local"
    echo ""
    
    print_info "📚 Documentation:"
    print_info "  - Getting Started: docs/GETTING-STARTED-THREE-NODE.md"
    print_info "  - Config Reference: docs/CONFIG-REFERENCE.md"
    print_info "  - CoreSrv repo: /opt/Orion-Sentinel-CoreSrv (on CoreSrv)"
    print_info "  - DNS repo: /opt/rpi-ha-dns-stack (on Pi #1)"
    print_info "  - NetSec repo: /opt/Orion-sentinel-netsec-ai (on Pi #2)"
    echo ""
    
    print_header "Happy monitoring! 🛡️🔒"
}

# Run main function
main "$@"
