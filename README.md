# Orion Sentinel Installer

A unified installer for deploying the **Orion Sentinel** home network security and privacy suite across two Raspberry Pis.

## Overview

Orion Sentinel is a comprehensive home network security solution that combines:

- **DNS & Privacy** (Pi #1): Ad-blocking, DNS filtering, and privacy protection via Pi-hole with optional high availability
- **Security & Monitoring** (Pi #2): Network security monitoring, intrusion detection, and AI-powered threat analysis

This installer repository provides simple bootstrap scripts to get you from "two fresh Raspberry Pis" to a fully operational Orion Sentinel deployment with just a handful of commands.

## Requirements

### Hardware

- **Two Raspberry Pi devices** (Raspberry Pi 4/5 recommended, 4GB+ RAM preferred)
- **Network connectivity** for both Pis
- **SSH access** to both Pis
- **SD cards** with Raspberry Pi OS 64-bit installed

### Software

- **Raspberry Pi OS 64-bit** (Bookworm or later recommended)
- **SSH enabled** on both Pis
- **Internet connection** during installation

### Network Setup

- **Pi #1 (DNS)**: Should be accessible to all devices on your network
- **Pi #2 (NSM)**: Should be connected to a network switch mirror/SPAN port for traffic monitoring (optional but recommended for full functionality)

## Quick Start

There are two ways to install Orion Sentinel:

1. **Local Installation**: SSH into each Pi and run the bootstrap scripts directly
2. **Remote Orchestration**: Run the orchestrator script from your local machine to set up both Pis remotely

### Option 1: Remote Orchestration (Recommended)

If you have SSH access to both Pis from your local machine, you can use the orchestrator script for a streamlined installation:

1. **Clone this repository on your local machine**

   ```bash
   git clone https://github.com/yorgosroussakis/orion-sentinel-installer.git
   cd orion-sentinel-installer
   ```

2. **Set up SSH key authentication** (if not already done)

   ```bash
   # Generate SSH key if you don't have one
   ssh-keygen -t ed25519
   
   # Copy your SSH key to both Pis
   ssh-copy-id pi@<pi1-ip-address>
   ssh-copy-id pi@<pi2-ip-address>
   ```

3. **Run the orchestrator script**

   ```bash
   # Install on both Pis
   ./scripts/orchestrate-install.sh --pi1 pi1.local --pi2 pi2.local
   
   # Or use IP addresses
   ./scripts/orchestrate-install.sh --pi1 192.168.1.10 --pi2 192.168.1.11
   
   # Or install only DNS on Pi #1
   ./scripts/orchestrate-install.sh --pi1 pi-dns.local --dns-only
   
   # Or install only NSM on Pi #2
   ./scripts/orchestrate-install.sh --pi2 pi-nsm.local --nsm-only
   ```

4. **Configure your network**
   - Set your router's DNS server to your Pi #1's IP address
   - Connect Pi #2 to a network mirror/SPAN port (optional but recommended)

### Option 2: Local Installation

If you prefer to install directly on each Pi:

#### Pi #1: DNS & Privacy Setup

1. **SSH into your first Raspberry Pi**

   ```bash
   ssh pi@<pi1-ip-address>
   ```

2. **Clone this repository**

   ```bash
   git clone https://github.com/yorgosroussakis/orion-sentinel-installer.git
   cd orion-sentinel-installer
   ```

3. **Run the DNS bootstrap script**

   ```bash
   ./scripts/bootstrap-pi1-dns.sh
   ```

4. **Configure your router**
   - Set your router's DNS server to your Pi #1's IP address
   - All devices on your network will now use Pi-hole for DNS

#### Pi #2: Security & Monitoring Setup

1. **SSH into your second Raspberry Pi**

   ```bash
   ssh pi@<pi2-ip-address>
   ```

2. **Clone this repository**

   ```bash
   git clone https://github.com/yorgosroussakis/orion-sentinel-installer.git
   cd orion-sentinel-installer
   ```

3. **Run the NSM bootstrap script**

   ```bash
   ./scripts/bootstrap-pi2-nsm.sh
   ```

4. **Access the dashboards**
   - Grafana: `http://<pi2-ip>:3000` (default: admin/admin)
   - NSM Wizard: `http://<pi2-ip>:8081` (if available)

## What Gets Installed

### Pi #1 (DNS & Privacy)

The bootstrap script will:
- ✅ Install Docker CE and Docker Compose
- ✅ Clone the [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/orion-sentinel-dns-ha) repository
- ✅ Run the DNS installation script (single-node mode by default)
- ✅ Set up Pi-hole for network-wide ad blocking
- ✅ Configure optional high availability with Keepalived

**Default installation location**: `~/orion/orion-sentinel-dns-ha`

### Pi #2 (Security & Monitoring)

The bootstrap script will:
- ✅ Install Docker CE and Docker Compose
- ✅ Clone the [orion-sentinel-nsm-ai](https://github.com/yorgosroussakis/orion-sentinel-nsm-ai) repository
- ✅ Run the NSM installation script
- ✅ Set up network monitoring with Suricata
- ✅ Deploy Grafana dashboards for visualization
- ✅ Configure AI-powered threat detection

**Default installation location**: `~/orion/orion-sentinel-nsm-ai`

## Post-Installation

After running the bootstrap scripts:

1. **Review the output messages** for access URLs and credentials
2. **Check the individual repository documentation** for advanced configuration:
   - [DNS HA Documentation](https://github.com/yorgosroussakis/orion-sentinel-dns-ha)
   - [NSM AI Documentation](https://github.com/yorgosroussakis/orion-sentinel-nsm-ai)
3. **Configure high availability** (optional) by editing `.env` files in each repository
4. **Set up port mirroring** on your network switch for Pi #2 to monitor traffic

## Advanced Configuration

### High Availability DNS (Pi #1)

For DNS high availability with a second Pi:

1. Edit `~/orion/orion-sentinel-dns-ha/.env`
2. Configure `KEEPALIVED_VIRTUAL_IP` and related settings
3. Re-run the install script or restart services

See the [DNS HA documentation](https://github.com/yorgosroussakis/orion-sentinel-dns-ha) for details.

### Network Monitoring Interface (Pi #2)

To change the network interface being monitored:

1. Edit `~/orion/orion-sentinel-nsm-ai/.env`
2. Set `NSM_INTERFACE` to your desired interface (e.g., `eth0`)
3. Restart the services

See the [NSM AI documentation](https://github.com/yorgosroussakis/orion-sentinel-nsm-ai) for details.

### Environment Variable Configuration

You can customize the installation by setting environment variables before running the bootstrap scripts:

**Pi #1 (DNS) Variables:**
```bash
# Custom repository URL (e.g., for testing or forks)
export DNS_REPO_URL="https://github.com/youruser/orion-sentinel-dns-ha.git"

# Custom branch (e.g., for development or testing)
export DNS_REPO_BRANCH="develop"

# Custom installation directory
export ORION_BASE_DIR="$HOME/custom-orion"

# Then run the script
./scripts/bootstrap-pi1-dns.sh
```

**Pi #2 (NSM) Variables:**
```bash
# Custom repository URL
export NSM_REPO_URL="https://github.com/youruser/orion-sentinel-nsm-ai.git"

# Custom branch
export NSM_REPO_BRANCH="develop"

# Custom installation directory
export ORION_BASE_DIR="$HOME/custom-orion"

# Then run the script
./scripts/bootstrap-pi2-nsm.sh
```

### Checking System Status

Use the status script to quickly check if Docker containers are running:

```bash
./scripts/show-status.sh
```

This displays:
- Running Docker containers and their status
- Port mappings
- Container count summary
- Docker disk usage

## Troubleshooting

### Docker Permission Issues

If you get permission errors running Docker commands:

```bash
# Log out and back in, or run:
newgrp docker
```

### Repository Not Found

Ensure the component repositories exist:
- [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/orion-sentinel-dns-ha)
- [orion-sentinel-nsm-ai](https://github.com/yorgosroussakis/orion-sentinel-nsm-ai)

### Installation Fails

Check the logs in each component's directory:
- `~/orion/orion-sentinel-dns-ha/`
- `~/orion/orion-sentinel-nsm-ai/`

Run `docker compose logs` in the respective directories for detailed error messages.

## Documentation

For detailed step-by-step instructions, see:
- [Getting Started with Two Pis](docs/getting-started-two-pi.md) - Detailed setup guide
- [DNS HA Repository](https://github.com/yorgosroussakis/orion-sentinel-dns-ha) - DNS component docs
- [NSM AI Repository](https://github.com/yorgosroussakis/orion-sentinel-nsm-ai) - NSM component docs

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Home Network                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │   Pi #1 (DNS)    │         │  Pi #2 (NSM)     │     │
│  ├──────────────────┤         ├──────────────────┤     │
│  │ • Pi-hole        │         │ • Suricata IDS   │     │
│  │ • Unbound DNS    │         │ • Grafana        │     │
│  │ • Keepalived HA  │         │ • AI Detection   │     │
│  │ • Ad Blocking    │         │ • Threat Intel   │     │
│  └──────────────────┘         └──────────────────┘     │
│         ↑                              ↑                │
│         │                              │                │
│    DNS Queries              Network Mirror Port         │
└─────────────────────────────────────────────────────────┘
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - see [LICENSE](LICENSE) file for details

## Support

For issues specific to:
- **This installer**: Open an issue in this repository
- **DNS component**: See [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/orion-sentinel-dns-ha)
- **NSM component**: See [orion-sentinel-nsm-ai](https://github.com/yorgosroussakis/orion-sentinel-nsm-ai)

## Acknowledgments

Built for homelabbers and power users who want enterprise-grade network security at home.
