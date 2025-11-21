#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for Raspberry Pi #2 - Security & Monitoring
# This script sets up the Orion Sentinel NSM AI component

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Configuration (can be overridden via environment variables)
readonly ORION_BASE_DIR="${ORION_BASE_DIR:-$HOME/orion}"
readonly NSM_REPO_URL="${NSM_REPO_URL:-https://github.com/yorgosroussakis/orion-sentinel-nsm-ai.git}"
readonly NSM_REPO_BRANCH="${NSM_REPO_BRANCH:-main}"
readonly NSM_REPO_DIR="$ORION_BASE_DIR/orion-sentinel-nsm-ai"


main() {
    print_header "Orion Sentinel - Pi #2 Bootstrap (Security & Monitoring)"
    
    print_info "This script will install and configure the NSM & AI component"
    print_info "on this Raspberry Pi."
    echo ""
    
    # Check required commands
    require_cmd git
    require_cmd curl
    
    # Step 1: Install Docker
    install_docker
    
    # Step 2: Clone the NSM repository
    print_header "Cloning NSM Repository"
    clone_repo_if_missing "$NSM_REPO_URL" "$NSM_REPO_DIR" "$NSM_REPO_BRANCH"
    
    # Step 3: Run the NSM install script
    print_header "Running NSM Installation Script"
    
    if ! cd "$NSM_REPO_DIR"; then
        print_error "Failed to change to NSM directory: $NSM_REPO_DIR"
        print_error "Repository cloning may have failed. Please check the error messages above."
        exit 1
    fi
    
    # NOTE: This installer delegates to the component repository's install script.
    # The orion-sentinel-nsm-ai repository should provide a scripts/install.sh that:
    # - Sets the NSM interface (prompting user or auto-detecting)
    # - Starts the NSM stack with docker compose
    # If the install script is not present, manual configuration will be required.
    # See: https://github.com/yorgosroussakis/orion-sentinel-nsm-ai
    
    if [ -f "scripts/install.sh" ]; then
        print_info "Running NSM install script..."
        bash scripts/install.sh
    else
        print_warning "NSM install script not found at scripts/install.sh"
        print_info "Please run the installation manually from: $NSM_REPO_DIR"
        print_info ""
        print_info "Typical steps:"
        print_info "  1. cd $NSM_REPO_DIR"
        print_info "  2. Configure .env file with NSM_INTERFACE"
        print_info "  3. Run docker compose up -d"
    fi
    
    # Step 4: Print completion information
    print_header "Installation Complete!"
    
    local_ip=$(get_local_ip)
    
    echo ""
    print_info "Security & Monitoring component has been set up on Pi #2"
    echo ""
    print_info "📋 Access Points:"
    echo ""
    print_info "1. Grafana Dashboard:"
    print_info "   URL: http://$local_ip:3000"
    print_info "   Default credentials: admin/admin (you'll be prompted to change)"
    echo ""
    print_info "2. NSM Configuration Wizard (if available):"
    print_info "   URL: http://$local_ip:8081"
    print_info "   Use this to configure network monitoring settings"
    echo ""
    print_info "3. Additional Services:"
    print_info "   - Check docker compose ps in: $NSM_REPO_DIR"
    print_info "   - Review .env file for service configuration"
    echo ""
    print_info "4. Documentation:"
    print_info "   See $NSM_REPO_DIR/README.md for more details"
    echo ""
    
    print_header "Bootstrap Complete!"
    print_info "Your Security & Monitoring Pi is ready! 🎉"
    echo ""
    print_info "💡 Tip: Connect this Pi to your network's mirror/span port"
    print_info "   to monitor all network traffic."
}

# Run main function
main "$@"
