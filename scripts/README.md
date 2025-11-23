# Orion Sentinel Installer Scripts

This directory contains all the bootstrap and utility scripts for deploying the Orion Sentinel three-node stack.

## Available Scripts

### Bootstrap Scripts

#### bootstrap-coresrv.sh
Prepares the CoreSrv (Dell/server) as the central Single Pane of Glass (SPoG).

**Usage:**
```bash
./bootstrap-coresrv.sh
```

**What it does:**
- Installs Docker and Docker Compose
- Clones Orion-Sentinel-CoreSrv repository to `/opt/Orion-Sentinel-CoreSrv`
- Creates directory structure under `/srv/orion-sentinel-core`
- Generates environment file templates from examples
- Provides instructions for manual configuration steps

**Environment Variables:**
- `CORESRV_REPO_URL` - Custom repository URL (default: official repo)
- `CORESRV_REPO_BRANCH` - Custom branch (default: main)
- `CORESRV_REPO_DIR` - Installation directory (default: `/opt/Orion-Sentinel-CoreSrv`)
- `CORESRV_DATA_ROOT` - Data root directory (default: `/srv/orion-sentinel-core`)

---

#### bootstrap-pi1-dns.sh
Prepares Pi #1 as the DNS HA node and connects it to CoreSrv for centralized logging.

**Usage (Remote):**
```bash
export PI_DNS_HOST="192.168.1.100"
export CORESRV_IP="192.168.1.10"
./bootstrap-pi1-dns.sh
```

**Usage (Local - run on the Pi itself):**
```bash
export CORESRV_IP="192.168.1.10"
./bootstrap-pi1-dns.sh
# Leave PI_DNS_HOST empty when prompted
```

**What it does:**
- Installs Docker on the Pi (local or remote via SSH)
- Clones rpi-ha-dns-stack repository to `/opt/rpi-ha-dns-stack`
- Configures and starts the DNS stack (Pi-hole + Unbound)
- Deploys Promtail agent for log forwarding to CoreSrv Loki
- Creates Promtail config at `/etc/promtail/promtail-config.yml`

**Environment Variables:**
- `PI_DNS_HOST` - Pi hostname or IP for remote install (empty = local)
- `CORESRV_IP` - CoreSrv IP address (required for Promtail)
- `DNS_REPO_URL` - Custom repository URL
- `DNS_REPO_BRANCH` - Custom branch
- `DNS_REPO_DIR` - Installation directory (default: `/opt/rpi-ha-dns-stack`)
- `PROMTAIL_VERSION` - Promtail version (default: 2.9.3)

---

#### bootstrap-pi2-netsec.sh
Prepares Pi #2 as the NetSec node in SPoG mode (sending logs to CoreSrv).

**Usage (Remote):**
```bash
export PI_NETSEC_HOST="192.168.1.101"
export CORESRV_IP="192.168.1.10"
./bootstrap-pi2-netsec.sh
```

**Usage (Local - run on the Pi itself):**
```bash
export CORESRV_IP="192.168.1.10"
./bootstrap-pi2-netsec.sh
# Leave PI_NETSEC_HOST empty when prompted
```

**What it does:**
- Installs Docker on the Pi (local or remote via SSH)
- Clones Orion-sentinel-netsec-ai repository to `/opt/Orion-sentinel-netsec-ai`
- Configures `.env` for SPoG mode:
  - `LOKI_URL=http://CORESRV_IP:3100`
  - `LOCAL_OBSERVABILITY=false`
- Brings up NSM stack (`stacks/nsm/`)
- Brings up AI stack (`stacks/ai/`)

**Environment Variables:**
- `PI_NETSEC_HOST` - Pi hostname or IP for remote install (empty = local)
- `CORESRV_IP` - CoreSrv IP address (required)
- `NETSEC_REPO_URL` - Custom repository URL
- `NETSEC_REPO_BRANCH` - Custom branch
- `NETSEC_REPO_DIR` - Installation directory (default: `/opt/Orion-sentinel-netsec-ai`)

---

### Orchestration Scripts

#### deploy-orion-sentinel.sh
High-level orchestrator that deploys the entire three-node stack.

**Usage:**
```bash
./deploy-orion-sentinel.sh
```

**Interactive Mode:**
The script will prompt for:
- CoreSrv IP address
- Pi DNS hostname/IP
- Pi NetSec hostname/IP
- Optional: custom repository URLs and branches
- Confirmation before each major step

**Non-Interactive Mode:**
```bash
export CORESRV_IP="192.168.1.10"
export PI_DNS_HOST="192.168.1.100"
export PI_NETSEC_HOST="192.168.1.101"
./deploy-orion-sentinel.sh
```

**What it does:**
1. Gathers configuration parameters
2. Optionally bootstraps CoreSrv (if running on CoreSrv or confirmed by user)
3. Bootstraps Pi #1 (DNS) using bootstrap-pi1-dns.sh
4. Bootstraps Pi #2 (NetSec) using bootstrap-pi2-netsec.sh
5. Provides comprehensive deployment checklist and validation steps

---

### Utility Scripts

#### common.sh
Shared helper functions used by all bootstrap scripts.

**Functions:**

- `print_header()` - Print formatted section headers
- `print_info()` - Print info messages
- `print_warning()` - Print warning messages
- `print_error()` - Print error messages
- `require_cmd()` - Check if required command exists
- `confirm()` - Yes/no prompt with validation
- `run_ssh()` - Execute SSH command with error handling
- `ensure_docker_installed()` - Install Docker on local or remote system
- `install_docker()` - Install Docker locally (legacy, called by ensure_docker_installed)
- `clone_repo_if_missing()` - Clone git repo or update if exists
- `get_local_ip()` - Get local IP address
- `wait_for_confirmation()` - Wait for user to press Enter

**Usage:**
```bash
# In other scripts:
source "$SCRIPT_DIR/common.sh"

# Then use the functions:
print_header "My Section"
require_cmd git
if confirm "Proceed?"; then
    echo "User confirmed"
fi
```

---

#### show-status.sh
Display Docker container status on the current machine.

**Usage:**
```bash
./show-status.sh
```

**What it shows:**
- Running Docker containers with status and ports
- Container count summary
- Docker disk usage

---

## Common Usage Patterns

### Full Three-Node Deployment

**Option 1: Use orchestrator (recommended)**
```bash
./deploy-orion-sentinel.sh
# Follow interactive prompts
```

**Option 2: Manual step-by-step**
```bash
# Step 1: Bootstrap CoreSrv (on CoreSrv machine)
./bootstrap-coresrv.sh

# Step 2: Configure CoreSrv
cd /opt/Orion-Sentinel-CoreSrv/env
nano .env.core        # Set Authelia secrets
nano .env.monitoring  # Set Grafana credentials

# Step 3: Start CoreSrv services
cd /opt/Orion-Sentinel-CoreSrv
./orionctl.sh up-core
./orionctl.sh up-observability

# Step 4: Bootstrap DNS Pi (from laptop or CoreSrv)
cd ~/Orion-sentinel-installer
export PI_DNS_HOST="192.168.1.100"
export CORESRV_IP="192.168.1.10"
./scripts/bootstrap-pi1-dns.sh

# Step 5: Bootstrap NetSec Pi (from laptop or CoreSrv)
export PI_NETSEC_HOST="192.168.1.101"
export CORESRV_IP="192.168.1.10"
./scripts/bootstrap-pi2-netsec.sh
```

### Local Installation on Pis

If you prefer to SSH into each Pi and run the script locally:

**On DNS Pi:**
```bash
ssh pi@192.168.1.100
git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git
cd Orion-sentinel-installer
export CORESRV_IP="192.168.1.10"
./scripts/bootstrap-pi1-dns.sh
# Leave PI_DNS_HOST empty when prompted
```

**On NetSec Pi:**
```bash
ssh pi@192.168.1.101
git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git
cd Orion-sentinel-installer
export CORESRV_IP="192.168.1.10"
./scripts/bootstrap-pi2-netsec.sh
# Leave PI_NETSEC_HOST empty when prompted
```

### Using Custom Repositories

For development or testing with forked repositories:

```bash
export DNS_REPO_URL="https://github.com/youruser/rpi-ha-dns-stack.git"
export DNS_REPO_BRANCH="develop"
export PI_DNS_HOST="192.168.1.100"
export CORESRV_IP="192.168.1.10"
./bootstrap-pi1-dns.sh
```

### Updating an Existing Installation

To update and redeploy (scripts are idempotent):

```bash
# Re-run bootstrap scripts with same parameters
export PI_DNS_HOST="192.168.1.100"
export CORESRV_IP="192.168.1.10"
./bootstrap-pi1-dns.sh
# Script will detect existing installation and offer to pull latest changes
```

---

## Error Handling

All scripts use `set -euo pipefail` for fail-fast behavior:
- Exit on any command failure
- Exit on undefined variables
- Exit on pipeline failures

Scripts source `common.sh` which provides:
- Colored output for easy identification of errors/warnings
- `require_cmd` to validate dependencies upfront
- Error messages with context

---

## Troubleshooting

### SSH Connection Issues

If remote bootstrap scripts fail to connect:
```bash
# Test SSH access
ssh pi@192.168.1.100

# If SSH key not set up:
ssh-copy-id pi@192.168.1.100

# Or specify key explicitly:
ssh -i ~/.ssh/id_rsa pi@192.168.1.100
```

### Docker Permission Errors

If you get Docker permission errors:
```bash
sudo usermod -aG docker $USER
# Then log out and back in, or:
newgrp docker
```

### Script Not Executable

If you get "permission denied":
```bash
chmod +x scripts/*.sh
```

---

## Helper Functions Reference

### print_header()
```bash
print_header "Section Title"
# Outputs:
# ========================================
#   Section Title
# ========================================
```

### confirm()
```bash
if confirm "Are you sure?"; then
    echo "User confirmed"
else
    echo "User declined"
fi
```

### run_ssh()
```bash
run_ssh "user@host" "docker ps"
# Runs command on remote host with error handling
```

### ensure_docker_installed()
```bash
# Local installation:
ensure_docker_installed

# Remote installation:
ensure_docker_installed "user@host"
```

---

## See Also

- [Getting Started Guide](../docs/GETTING-STARTED-THREE-NODE.md)
- [Configuration Reference](../docs/CONFIG-REFERENCE.md)
- [Main README](../README.md)
