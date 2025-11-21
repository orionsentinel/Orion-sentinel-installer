#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for Raspberry Pi #1 - DNS & Privacy
# This script sets up the Orion Sentinel DNS HA component

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration (can be overridden via environment variables)
readonly ORION_BASE_DIR="${ORION_BASE_DIR:-$HOME/orion}"
readonly DNS_REPO_URL="${DNS_REPO_URL:-https://github.com/yorgosroussakis/orion-sentinel-dns-ha.git}"
readonly DNS_REPO_BRANCH="${DNS_REPO_BRANCH:-main}"
readonly DNS_REPO_DIR="$ORION_BASE_DIR/orion-sentinel-dns-ha"


main() {
    print_header "Orion Sentinel - Pi #1 Bootstrap (DNS & Privacy)"
    
    print_info "This script will install and configure the DNS & Privacy component"
    print_info "on this Raspberry Pi."
    echo ""
    
    # Check required commands
    require_cmd git
    require_cmd curl
    
    # Step 1: Install Docker
    install_docker
    
    # Step 2: Clone the DNS repository
    print_header "Cloning DNS Repository"
    clone_repo_if_missing "$DNS_REPO_URL" "$DNS_REPO_DIR" "$DNS_REPO_BRANCH"
    
    # Step 3: Run the DNS install script
    print_header "Running DNS Installation Script"
    
    if ! cd "$DNS_REPO_DIR"; then
        print_error "Failed to change to DNS directory: $DNS_REPO_DIR"
        print_error "Repository cloning may have failed. Please check the error messages above."
        exit 1
    fi
    
    # NOTE: This installer delegates to the component repository's install script.
    # The orion-sentinel-dns-ha repository should provide a scripts/install.sh
    # that handles the DNS setup in single-node mode by default.
    # If the install script is not present, manual configuration will be required.
    # See: https://github.com/yorgosroussakis/orion-sentinel-dns-ha
    
    if [ -f "scripts/install.sh" ]; then
        print_info "Running DNS install script..."
        bash scripts/install.sh
    else
        print_warning "DNS install script not found at scripts/install.sh"
        print_info "Please run the installation manually from: $DNS_REPO_DIR"
        print_info ""
        print_info "Typical steps:"
        print_info "  1. cd $DNS_REPO_DIR"
        print_info "  2. Configure .env file for single-node or HA mode"
        print_info "  3. Run docker compose up -d"
    fi
    
    # Step 4: Print completion information
    print_header "Installation Complete!"
    
    local_ip=$(get_local_ip)
    
    echo ""
    print_info "DNS & Privacy component has been set up on Pi #1"
    echo ""
    print_info "📋 Next Steps:"
    echo ""
    print_info "1. Pi-hole Admin Interface:"
    print_info "   URL: http://$local_ip/admin"
    print_info "   (Check the .env file in $DNS_REPO_DIR for the admin password)"
    echo ""
    print_info "2. Configure your router:"
    print_info "   Set DNS server to: $local_ip"
    print_info "   (Or use the VIP if you configured HA mode)"
    echo ""
    print_info "3. For High Availability setup:"
    print_info "   - Edit the .env file in: $DNS_REPO_DIR"
    print_info "   - Configure KEEPALIVED_VIRTUAL_IP and other HA settings"
    print_info "   - Re-run the install script or restart services"
    echo ""
    print_info "4. Documentation:"
    print_info "   See $DNS_REPO_DIR/README.md for more details"
    echo ""
    
    print_header "Bootstrap Complete!"
    print_info "Your DNS & Privacy Pi is ready! 🎉"
}

# Run main function
main "$@"
