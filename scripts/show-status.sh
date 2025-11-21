#!/usr/bin/env bash
set -euo pipefail

# Status script to show Docker container status on Orion Sentinel Pis

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common helpers
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

main() {
    print_header "Orion Sentinel - Docker Status"
    
    # Check if Docker is available
    require_cmd docker
    
    # Check if user can run Docker commands
    if ! docker ps &>/dev/null; then
        print_error "Cannot connect to Docker daemon. You may need to:"
        echo "  1. Run this script with sudo, or"
        echo "  2. Add your user to the docker group: sudo usermod -aG docker \$USER"
        echo "  3. Log out and back in for group changes to take effect"
        exit 1
    fi
    
    print_info "Docker containers on this Pi:"
    echo ""
    
    # Display running containers in a table format
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    
    # Count containers
    local running_count
    running_count=$(docker ps -q | wc -l)
    local total_count
    total_count=$(docker ps -a -q | wc -l)
    
    print_info "Summary: $running_count running / $total_count total containers"
    
    echo ""
    
    # Show Docker disk usage
    print_info "Docker disk usage:"
    docker system df
    
    echo ""
}

# Run main function
main "$@"
