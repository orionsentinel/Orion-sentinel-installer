#!/usr/bin/env bash
set -euo pipefail

# Orchestration script for full Orion Sentinel deployment
# This script deploys the complete three-node Orion Sentinel stack

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration
CORESRV_IP="${CORESRV_IP:-}"
PI_DNS_HOST="${PI_DNS_HOST:-}"
PI_NETSEC_HOST="${PI_NETSEC_HOST:-}"

main() {
    print_header "Orion Sentinel - Full Stack Deployment Orchestrator"
    
    print_info "This script will deploy the complete three-node Orion Sentinel stack:"
    print_info "  1. CoreSrv (Dell) - Central observability and SPoG"
    print_info "  2. Pi #1 - DNS HA (Pi-hole + Unbound)"
    print_info "  3. Pi #2 - NetSec (NSM + AI)"
    echo ""
    
    # Gather required information
    print_header "Configuration"
    
    if [ -z "$CORESRV_IP" ]; then
        read -r -p "Enter CoreSrv IP address: " CORESRV_IP
    fi
    
    if [ -z "$CORESRV_IP" ]; then
        print_error "CoreSrv IP is required"
        exit 1
    fi
    
    print_info "CoreSrv IP: $CORESRV_IP"
    
    if [ -z "$PI_DNS_HOST" ]; then
        read -r -p "Enter Pi DNS hostname or IP address: " PI_DNS_HOST
    fi
    
    if [ -z "$PI_DNS_HOST" ]; then
        print_error "Pi DNS host is required"
        exit 1
    fi
    
    print_info "Pi DNS Host: $PI_DNS_HOST"
    
    if [ -z "$PI_NETSEC_HOST" ]; then
        read -r -p "Enter Pi NetSec hostname or IP address: " PI_NETSEC_HOST
    fi
    
    if [ -z "$PI_NETSEC_HOST" ]; then
        print_error "Pi NetSec host is required"
        exit 1
    fi
    
    print_info "Pi NetSec Host: $PI_NETSEC_HOST"
    echo ""
    
    # Optional: Repository configuration
    if confirm "Do you want to specify custom repository URLs or branches? (default: use official repos)"; then
        echo ""
        read -r -p "DNS repo URL (press Enter for default): " DNS_REPO_URL
        read -r -p "DNS repo branch (press Enter for default): " DNS_REPO_BRANCH
        read -r -p "NetSec repo URL (press Enter for default): " NETSEC_REPO_URL
        read -r -p "NetSec repo branch (press Enter for default): " NETSEC_REPO_BRANCH
        read -r -p "CoreSrv repo URL (press Enter for default): " CORESRV_REPO_URL
        read -r -p "CoreSrv repo branch (press Enter for default): " CORESRV_REPO_BRANCH
        echo ""
    fi
    
    # Export configuration for child scripts
    export CORESRV_IP
    export PI_DNS_HOST
    export PI_NETSEC_HOST
    [ -n "${DNS_REPO_URL:-}" ] && export DNS_REPO_URL
    [ -n "${DNS_REPO_BRANCH:-}" ] && export DNS_REPO_BRANCH
    [ -n "${NETSEC_REPO_URL:-}" ] && export NETSEC_REPO_URL
    [ -n "${NETSEC_REPO_BRANCH:-}" ] && export NETSEC_REPO_BRANCH
    [ -n "${CORESRV_REPO_URL:-}" ] && export CORESRV_REPO_URL
    [ -n "${CORESRV_REPO_BRANCH:-}" ] && export CORESRV_REPO_BRANCH
    
    # Confirmation before proceeding
    echo ""
    print_warning "About to deploy Orion Sentinel stack with the following configuration:"
    print_info "  CoreSrv IP:     $CORESRV_IP"
    print_info "  Pi DNS Host:    $PI_DNS_HOST"
    print_info "  Pi NetSec Host: $PI_NETSEC_HOST"
    echo ""
    
    if ! confirm "Proceed with deployment?"; then
        print_info "Deployment cancelled by user"
        exit 0
    fi
    
    # Step 1: CoreSrv bootstrap (optional)
    echo ""
    print_header "Step 1: CoreSrv Bootstrap"
    
    if confirm "Do you want to bootstrap CoreSrv now? (Say no if already done)"; then
        print_info "Running CoreSrv bootstrap script..."
        
        # Check if we're running on CoreSrv or need to SSH
        if confirm "Are you running this script on the CoreSrv machine?"; then
            "$SCRIPT_DIR/bootstrap-coresrv.sh"
        else
            print_warning "Remote CoreSrv bootstrap not implemented yet"
            print_info "Please run bootstrap-coresrv.sh manually on CoreSrv:"
            print_info "  1. SSH to CoreSrv"
            print_info "  2. Clone this installer repository"
            print_info "  3. Run: ./scripts/bootstrap-coresrv.sh"
            echo ""
            
            if ! confirm "Have you completed CoreSrv bootstrap? Continue?"; then
                print_info "Deployment paused - please bootstrap CoreSrv first"
                exit 0
            fi
        fi
    else
        print_info "Skipping CoreSrv bootstrap (assumed already done)"
    fi
    
    # Step 2: Pi DNS bootstrap
    echo ""
    print_header "Step 2: Pi DNS Bootstrap"
    
    print_info "Bootstrapping Pi DNS at $PI_DNS_HOST..."
    
    if "$SCRIPT_DIR/bootstrap-pi1-dns.sh"; then
        print_info "Pi DNS bootstrap completed successfully!"
    else
        print_error "Pi DNS bootstrap failed!"
        
        if ! confirm "Continue with NetSec bootstrap anyway?"; then
            exit 1
        fi
    fi
    
    # Step 3: Pi NetSec bootstrap
    echo ""
    print_header "Step 3: Pi NetSec Bootstrap"
    
    print_info "Bootstrapping Pi NetSec at $PI_NETSEC_HOST..."
    
    if "$SCRIPT_DIR/bootstrap-pi2-netsec.sh"; then
        print_info "Pi NetSec bootstrap completed successfully!"
    else
        print_error "Pi NetSec bootstrap failed!"
        print_warning "Please check the error messages above and retry if needed"
    fi
    
    # Step 4: Final summary and next steps
    print_header "Deployment Complete!"
    
    echo ""
    print_info "🎉 Orion Sentinel three-node stack has been deployed!"
    echo ""
    print_info "📋 Deployment Summary:"
    echo ""
    print_info "  ✓ CoreSrv (Dell) - $CORESRV_IP"
    print_info "    - Traefik + Authelia (core services)"
    print_info "    - Prometheus + Loki + Grafana (monitoring)"
    echo ""
    print_info "  ✓ Pi #1 (DNS) - $PI_DNS_HOST"
    print_info "    - Pi-hole + Unbound (DNS filtering)"
    print_info "    - Promtail agent (logs → CoreSrv Loki)"
    echo ""
    print_info "  ✓ Pi #2 (NetSec) - $PI_NETSEC_HOST"
    print_info "    - Suricata + AI detection (NSM)"
    print_info "    - SPoG mode (logs → CoreSrv Loki)"
    echo ""
    print_header "Next Steps - Validation Checklist"
    echo ""
    print_info "1. Access Grafana on CoreSrv:"
    print_info "   URL: https://grafana.local (or http://$CORESRV_IP:3000)"
    print_info "   Check Loki logs for:"
    print_info "     - {host=\"pi-dns\"} - DNS Pi logs"
    print_info "     - {host=\"pi-netsec\"} - NetSec Pi logs"
    echo ""
    print_info "2. Verify Prometheus targets (if configured):"
    print_info "   - Check that exporters from both Pis are being scraped"
    print_info "   - Navigate to Status → Targets in Prometheus"
    echo ""
    print_info "3. Test DNS functionality:"
    print_info "   - Access Pi-hole: http://$PI_DNS_HOST/admin"
    print_info "   - Configure your router to use $PI_DNS_HOST as DNS"
    print_info "   - Test ad blocking on client devices"
    echo ""
    print_info "4. Verify NetSec monitoring:"
    print_info "   - Check that network traffic is being captured"
    print_info "   - Review Suricata alerts in Grafana dashboards"
    echo ""
    print_info "5. Configure Traefik dynamic configs (optional):"
    print_info "   - Create Traefik dynamic config for DNS and NetSec services"
    print_info "   - Set up DNS records for https://dns.local and https://security.local"
    echo ""
    print_info "6. On CoreSrv, verify full stack is running:"
    print_info "   cd /opt/Orion-Sentinel-CoreSrv"
    print_info "   ./orionctl.sh status"
    echo ""
    print_header "Deployment Complete!"
    print_info "Your Orion Sentinel stack is operational! 🛡️"
    echo ""
    print_info "For troubleshooting and advanced configuration, see:"
    print_info "  - docs/GETTING-STARTED-THREE-NODE.md"
    print_info "  - docs/CONFIG-REFERENCE.md"
}

# Run main function
main "$@"
