# Orion Sentinel Bootstrap Scripts

This directory contains bootstrap and orchestration scripts for deploying Orion Sentinel in various configurations.

## Quick Reference

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `common.sh` | Shared utilities for all scripts | Sourced by other scripts |
| `bootstrap-coresrv.sh` | Set up CoreSrv (Dell server) | Three-node architecture |
| `bootstrap-pi1-dns.sh` | Set up Pi #1 (DNS) | Both architectures |
| `bootstrap-pi2-netsec.sh` | Set up Pi #2 (NetSec) in SPoG mode | Three-node architecture |
| `bootstrap-pi2-nsm.sh` | Set up Pi #2 (NSM) standalone | Two-Pi architecture (legacy) |
| `deploy-orion-sentinel.sh` | Full orchestration for all nodes | Three-node architecture |
| `orchestrate-install.sh` | Orchestration for two Pis | Two-Pi architecture (legacy) |
| `show-status.sh` | Display Docker container status | Any architecture |

## Architecture Overview

### Three-Node Architecture (Recommended)

```
CoreSrv (Dell) + Pi #1 (DNS) + Pi #2 (NetSec in SPoG mode)
```

**Use these scripts:**
1. `bootstrap-coresrv.sh` - on CoreSrv
2. `bootstrap-pi1-dns.sh --coresrv <ip>` - for Pi #1
3. `bootstrap-pi2-netsec.sh --coresrv <ip>` - for Pi #2

**Or use the full orchestrator:**
```bash
./deploy-orion-sentinel.sh --coresrv <ip> --pi-dns <host> --pi-netsec <host>
```

### Two-Pi Architecture (Legacy)

```
Pi #1 (DNS) + Pi #2 (NSM standalone)
```

**Use these scripts:**
1. `bootstrap-pi1-dns.sh` - for Pi #1 (no CoreSrv)
2. `bootstrap-pi2-nsm.sh` - for Pi #2
3. Or `orchestrate-install.sh --pi1 <host> --pi2 <host>`

## Script Details

### common.sh

**Purpose**: Provides shared utility functions for all bootstrap scripts.

**Key Functions**:
- `print_header()`, `print_info()`, `print_error()`, `print_warning()` - Formatted output
- `require_cmd()` - Validate required commands exist
- `confirm()` - Yes/No prompts
- `run_ssh()` - Execute commands over SSH with error handling
- `install_docker()` - Install Docker CE locally
- `install_docker_remote()` - Install Docker CE on remote host
- `ensure_docker_installed()` - Ensure Docker is installed
- `clone_repo_if_missing()` - Clone or update a git repository
- `get_local_ip()` - Get the local IP address

**Note**: This script is sourced by other scripts and should not be run directly.

### bootstrap-coresrv.sh

**Purpose**: Bootstrap the CoreSrv (Dell server) as the central Single Pane of Glass.

**What it does**:
- Installs Docker CE
- Clones/updates Orion-Sentinel-CoreSrv repository to `/opt/Orion-Sentinel-CoreSrv`
- Creates directory structure: `/srv/orion-sentinel-core/{config,monitoring,cloud,backups}`
- Generates environment files from examples
- Auto-generates Authelia secrets
- Optionally starts Traefik, Authelia, Loki, Grafana, Prometheus

**Usage**:
```bash
# Run on CoreSrv directly
./scripts/bootstrap-coresrv.sh
```

**Environment Variables**:
- `CORESRV_REPO_URL` - CoreSrv repository URL (default: official repo)
- `CORESRV_REPO_BRANCH` - Git branch (default: main)
- `CORESRV_REPO_DIR` - Installation directory (default: /opt/Orion-Sentinel-CoreSrv)
- `ORION_DATA_ROOT` - Data root directory (default: /srv/orion-sentinel-core)

### bootstrap-pi1-dns.sh

**Purpose**: Bootstrap Pi #1 as the DNS server with optional CoreSrv integration.

**What it does**:
- Installs Docker CE
- Clones/updates DNS repository to `/opt/rpi-ha-dns-stack`
- Generates `.env` configuration
- Starts Pi-hole and Unbound
- If CoreSrv IP provided: deploys Promtail to send logs to CoreSrv

**Usage**:
```bash
# Local mode (run on Pi #1 directly)
./scripts/bootstrap-pi1-dns.sh
./scripts/bootstrap-pi1-dns.sh --coresrv 192.168.1.50

# Remote mode (run from workstation)
./scripts/bootstrap-pi1-dns.sh --host pi-dns.local --coresrv 192.168.1.50
```

**Options**:
- `--host <hostname>` - Pi hostname/IP (enables remote mode)
- `--coresrv <ip>` - CoreSrv IP for Promtail logging
- `-h, --help` - Show help message

**Environment Variables**:
- `DNS_REPO_URL` - DNS repository URL
- `DNS_REPO_BRANCH` - Git branch (default: main)
- `DNS_REPO_DIR` - Installation directory (default: /opt/rpi-ha-dns-stack)

### bootstrap-pi2-netsec.sh

**Purpose**: Bootstrap Pi #2 as the NetSec node in Single Pane of Glass mode.

**What it does**:
- Installs Docker CE
- Clones/updates NetSec repository to `/opt/Orion-sentinel-netsec-ai`
- Generates `.env` with `LOKI_URL=http://<coresrv>:3100` and `LOCAL_OBSERVABILITY=false`
- Starts NSM stack (Suricata, etc.)
- Starts AI stack
- Configures Promtail (if part of the repo)

**Usage**:
```bash
# Local mode (run on Pi #2 directly)
./scripts/bootstrap-pi2-netsec.sh --coresrv 192.168.1.50

# Remote mode (run from workstation)
./scripts/bootstrap-pi2-netsec.sh --host pi-netsec.local --coresrv 192.168.1.50
```

**Options**:
- `--host <hostname>` - Pi hostname/IP (enables remote mode)
- `--coresrv <ip>` - **REQUIRED** CoreSrv IP for SPoG mode
- `-h, --help` - Show help message

**Environment Variables**:
- `NETSEC_REPO_URL` - NetSec repository URL
- `NETSEC_REPO_BRANCH` - Git branch (default: main)
- `NETSEC_REPO_DIR` - Installation directory (default: /opt/Orion-sentinel-netsec-ai)

### deploy-orion-sentinel.sh

**Purpose**: Full orchestration script for deploying all three nodes.

**What it does**:
- Prompts to set up CoreSrv (or can skip if already done)
- Runs `bootstrap-pi1-dns.sh` for Pi #1
- Runs `bootstrap-pi2-netsec.sh` for Pi #2
- Prints comprehensive validation checklist

**Usage**:
```bash
# Full deployment
./scripts/deploy-orion-sentinel.sh \
  --coresrv 192.168.1.50 \
  --pi-dns pi1.local \
  --pi-netsec pi2.local

# Skip CoreSrv setup (if already configured)
./scripts/deploy-orion-sentinel.sh \
  --skip-coresrv \
  --coresrv 192.168.1.50 \
  --pi-dns pi1.local \
  --pi-netsec pi2.local
```

**Options**:
- `--coresrv <ip>` - **REQUIRED** CoreSrv IP address
- `--pi-dns <host>` - **REQUIRED** Pi #1 hostname/IP
- `--pi-netsec <host>` - **REQUIRED** Pi #2 hostname/IP
- `--skip-coresrv` - Skip CoreSrv setup (assume already configured)
- `-h, --help` - Show help message

### Legacy Scripts

#### bootstrap-pi2-nsm.sh

**Purpose**: Bootstrap Pi #2 in standalone mode (two-Pi architecture).

**Note**: For new deployments, use `bootstrap-pi2-netsec.sh` with CoreSrv instead.

**Usage**:
```bash
# Run locally on Pi #2
./scripts/bootstrap-pi2-nsm.sh
```

#### orchestrate-install.sh

**Purpose**: Orchestrate deployment for two-Pi architecture.

**Note**: For new deployments with a server, use `deploy-orion-sentinel.sh` instead.

**Usage**:
```bash
./scripts/orchestrate-install.sh --pi1 pi1.local --pi2 pi2.local
./scripts/orchestrate-install.sh --pi1 pi1.local --dns-only
./scripts/orchestrate-install.sh --pi2 pi2.local --nsm-only
```

### show-status.sh

**Purpose**: Display Docker container status on any node.

**Usage**:
```bash
./scripts/show-status.sh
```

Shows:
- Running containers and their status
- Port mappings
- Container count summary
- Docker disk usage

## Common Utilities Reference

All scripts source `common.sh` which provides these utilities:

### Output Functions

```bash
print_header "Section Title"        # Print a section header
print_info "Information message"    # Print an info message
print_error "Error message"         # Print an error to stderr
print_warning "Warning message"     # Print a warning
```

### Validation Functions

```bash
require_cmd git                     # Exit if command not found
confirm "Proceed?"                  # Yes/No prompt (returns 0 for yes)
```

### SSH Functions

```bash
run_ssh host "command"              # Run command over SSH with error handling
```

### Docker Functions

```bash
install_docker                      # Install Docker CE locally
install_docker_remote host          # Install Docker CE on remote host
ensure_docker_installed             # Ensure Docker is installed locally
```

### Git Functions

```bash
clone_repo_if_missing url dir [branch]   # Clone or update repository
```

### Network Functions

```bash
get_local_ip                        # Get local IP address
```

## Best Practices

1. **Always use `--help`**: All scripts provide usage information with `--help`
2. **Test SSH access first**: Before using remote mode, verify SSH connectivity
3. **Use static IPs**: Configure static IPs or DHCP reservations for all nodes
4. **Run CoreSrv first**: In three-node architecture, always set up CoreSrv before the Pis
5. **Check script output**: Scripts print comprehensive summaries - review them carefully
6. **Validate in Grafana**: After deployment, verify logs appear in Loki on CoreSrv

## Troubleshooting

### Script Fails with "command not found"

The script will tell you which command is missing. Install it:
```bash
sudo apt-get update
sudo apt-get install <missing-command>
```

### SSH Connection Fails

Check:
- Network connectivity: `ping <host>`
- SSH is enabled on target
- SSH keys are set up: `ssh-copy-id user@<host>`
- Firewall rules allow SSH

### Docker Permission Errors

After Docker installation, you may need to:
```bash
newgrp docker      # Or log out and back in
```

### Scripts Hang or Timeout

Check:
- Network connectivity
- DNS resolution
- Firewall rules
- Sufficient disk space

## Advanced Usage

### Custom Repository URLs

Override repository URLs for testing or forks:

```bash
export DNS_REPO_URL="https://github.com/myuser/custom-dns-repo.git"
export DNS_REPO_BRANCH="develop"
./scripts/bootstrap-pi1-dns.sh
```

### Custom Installation Directories

Change installation paths:

```bash
export DNS_REPO_DIR="/custom/path/dns"
export NETSEC_REPO_DIR="/custom/path/netsec"
```

### Debugging

Enable verbose output:
```bash
bash -x ./scripts/bootstrap-pi1-dns.sh --help
```

## Security Considerations

1. **Secrets**: CoreSrv bootstrap auto-generates Authelia secrets
2. **SSH Keys**: Use SSH keys, not passwords
3. **Firewall**: Configure firewall rules appropriately
4. **Updates**: Keep Docker images and packages updated
5. **Backups**: Regularly backup `.env` files and Grafana dashboards

## Contributing

When adding new scripts:
1. Source `common.sh` for shared utilities
2. Use `set -euo pipefail` for fail-fast behavior
3. Provide `--help` output with usage examples
4. Include comprehensive error handling
5. Print clear summaries at the end
6. Run `shellcheck` before committing

## See Also

- [Getting Started with Three-Node Architecture](../docs/GETTING-STARTED-THREE-NODE.md)
- [Configuration Reference](../docs/CONFIG-REFERENCE.md)
- [Getting Started with Two Pis](../docs/getting-started-two-pi.md)
