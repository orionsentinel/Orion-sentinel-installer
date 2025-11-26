# Orion Sentinel Installer

A unified installer for deploying the **Orion Sentinel** home network security and privacy suite across multiple architectures.

## Overview

Orion Sentinel is a comprehensive home network security solution that supports two deployment architectures:

### Two-Pi Architecture (Original)

- **DNS & Privacy** (Pi #1): Ad-blocking, DNS filtering, and privacy protection via Pi-hole with optional high availability
- **Security & Monitoring** (Pi #2): Network security monitoring, intrusion detection, and AI-powered threat analysis

**Status**: Fully supported for simple two-Pi deployments.

### Three-Node Architecture with CoreSrv (NEW) ⭐

A more advanced architecture with centralized observability:

- **CoreSrv (Dell/Server)**: Central Single Pane of Glass (SPoG) running Loki, Grafana, Prometheus, Traefik, and Authelia
- **Pi #1 (DNS)**: Pi-hole + Unbound with Promtail agent sending logs to CoreSrv
- **Pi #2 (NetSec)**: Network Security Monitoring + AI, configured in SPoG mode with all logs sent to CoreSrv

**Benefits**:
- Centralized monitoring and logging on a powerful server
- Better performance on Pis (no local Grafana/Loki overhead)
- Single dashboard for all components
- Enterprise-grade auth via Authelia
- Reverse proxy with SSL via Traefik

See [Getting Started with Three-Node Architecture](docs/GETTING-STARTED-THREE-NODE.md) for detailed setup instructions.

## Requirements

### Hardware

**For Two-Pi Architecture:**
- **Two Raspberry Pi devices** (Raspberry Pi 4/5 recommended, 4GB+ RAM preferred)
- **Network connectivity** for both Pis
- **SSH access** to both Pis
- **SD cards** with Raspberry Pi OS 64-bit installed

**For Three-Node Architecture (recommended):**
- **One x86 Server** (Dell, NUC, or similar - 16GB+ RAM recommended for CoreSrv)
- **Two Raspberry Pi 5** devices (8GB RAM recommended)
- **Network connectivity** for all three nodes
- **SSH access** to all nodes
- **Static IP addresses** or DHCP reservations recommended

### Software

- **Raspberry Pi OS 64-bit** (Bookworm or later recommended)
- **SSH enabled** on both Pis
- **Internet connection** during installation

### Network Setup

**For Two-Pi Architecture:**
- **Pi #1 (DNS)**: Should be accessible to all devices on your network
- **Pi #2 (NSM)**: Should be connected to a network switch mirror/SPAN port for traffic monitoring (optional but recommended for full functionality)

**For Three-Node Architecture:**
- **CoreSrv**: Central server with static IP, accessible from your workstation and both Pis
- **Pi #1 (DNS)**: Should be accessible to all devices on your network for DNS queries
- **Pi #2 (NetSec)**: Should be connected to a network switch mirror/SPAN port for traffic monitoring
- **Important**: Pis push logs to CoreSrv; CoreSrv never SSHs into Pis

## Quick Start

Choose your deployment architecture:

### Three-Node Architecture (CoreSrv + 2 Pis) - Recommended for Homelabs

**Best for**: Users with a server/NUC and want centralized monitoring

1. **Set up CoreSrv first** (on your Dell/server):

   ```bash
   ssh user@coresrv-ip
   git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git
   cd Orion-sentinel-installer
   ./scripts/bootstrap-coresrv.sh
   ```

2. **Deploy to both Pis** (from your workstation):

   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git
   cd Orion-sentinel-installer
   
   # Full orchestration
   ./scripts/deploy-orion-sentinel.sh \
     --coresrv 192.168.1.50 \
     --pi-dns pi1.local \
     --pi-netsec pi2.local
   ```

3. **Access Grafana on CoreSrv**:
   - URL: `http://<coresrv-ip>:3000`
   - View logs from both Pis in one place
   - Centralized dashboards and alerting

📖 **Detailed Guide**: [Getting Started with Three-Node Architecture](docs/GETTING-STARTED-THREE-NODE.md)

### Two-Pi Architecture (Standalone) - Optional Legacy Setup

**Best for**: Users without a dedicated server, want self-contained Pis

**Note**: This is a legacy deployment option. For better performance and centralized monitoring, use the three-node architecture above.

1. **Clone this repository on your local machine**

   ```bash
   git clone https://github.com/yorgosroussakis/orion-sentinel-installer.git
   cd orion-sentinel-installer
   ```

2. **Set up SSH key authentication** (if not already done)

   ```bash
   ssh-copy-id pi@<pi1-ip-address>
   ssh-copy-id pi@<pi2-ip-address>
   ```

3. **Run the bootstrap scripts individually**

   ```bash
   # Bootstrap Pi #1 (DNS) in standalone mode
   ./scripts/bootstrap-pi1-dns.sh --host pi1.local
   
   # Bootstrap Pi #2 (NSM) in standalone mode
   ./scripts/bootstrap-pi2-nsm.sh
   ```

4. **Configure your network**
   - Set your router's DNS server to your Pi #1's IP address
   - Connect Pi #2 to a network mirror/SPAN port (optional but recommended)

📙 **Detailed Guide**: [Getting Started with Two Pis](docs/getting-started-two-pi.md)

## What Gets Installed

### Three-Node Architecture

#### CoreSrv (Dell/Server)
- ✅ Docker CE and Docker Compose
- ✅ Traefik reverse proxy with SSL
- ✅ Authelia for authentication
- ✅ Loki for centralized log aggregation
- ✅ Grafana for visualization
- ✅ Prometheus for metrics collection (optional)
- ✅ Homepage dashboard (optional) - Links to all services

**Installation location**: `/opt/Orion-Sentinel-CoreSrv`

#### Pi #1 (DNS)
- ✅ Docker CE and Docker Compose
- ✅ Pi-hole for network-wide ad blocking
- ✅ Unbound for recursive DNS
- ✅ Keepalived for high availability (optional)
- ✅ Promtail agent sending logs to CoreSrv

**Installation location**: `/opt/rpi-ha-dns-stack`

#### Pi #2 (NetSec)
- ✅ Docker CE and Docker Compose
- ✅ Suricata for network monitoring
- ✅ AI-powered threat detection
- ✅ Configured in SPoG mode (logs sent to CoreSrv)
- ✅ Promtail agent (if part of the repo)

**Installation location**: `/opt/Orion-sentinel-netsec-ai`

### Two-Pi Architecture

#### Pi #1 (DNS & Privacy)

The bootstrap script will:
- ✅ Install Docker CE and Docker Compose
- ✅ Clone the DNS repository
- ✅ Run the DNS installation script (single-node mode by default)
- ✅ Set up Pi-hole for network-wide ad blocking
- ✅ Configure optional high availability with Keepalived

**Default installation location**: `~/orion/orion-sentinel-dns-ha`

#### Pi #2 (Security & Monitoring)

The bootstrap script will:
- ✅ Install Docker CE and Docker Compose
- ✅ Clone the NSM repository
- ✅ Run the NSM installation script
- ✅ Set up network monitoring with Suricata
- ✅ Deploy Grafana dashboards for visualization
- ✅ Configure AI-powered threat detection

**Default installation location**: `~/orion/orion-sentinel-nsm-ai`

## Documentation

### Three-Node Architecture (CoreSrv + 2 Pis)
- 📘 **[Getting Started Guide](docs/GETTING-STARTED-THREE-NODE.md)** - Complete setup walkthrough
- 📗 **[Configuration Reference](docs/CONFIG-REFERENCE.md)** - All configuration variables and settings
- 🏗️ **Architecture**: CoreSrv (SPoG) + DNS Pi + NetSec Pi

### Two-Pi Architecture (Standalone)
- 📙 **[Getting Started with Two Pis](docs/getting-started-two-pi.md)** - Original two-Pi setup guide

### Homepage Dashboard
- 🏠 **[Homepage](homepage/)** - Lightweight dashboard with links to all services

### Component Repositories
- [Orion-Sentinel-CoreSrv](https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv) - Central SPoG (Traefik, Loki, Grafana, Prometheus)
- [rpi-ha-dns-stack](https://github.com/yorgosroussakis/rpi-ha-dns-stack) - DNS HA component (Pi-hole + Unbound)
- [Orion-sentinel-netsec-ai](https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai) - NetSec component (NSM + AI)

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

## Architecture Diagrams

### Three-Node Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Orion Sentinel - Three Node               │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐      ┌─────────────────┐              │
│  │   Pi #1 (DNS)   │      │ Pi #2 (NetSec)  │              │
│  ├─────────────────┤      ├─────────────────┤              │
│  │ • Pi-hole       │      │ • Suricata IDS  │              │
│  │ • Unbound       │      │ • AI Detection  │              │
│  │ • Promtail ────┐│      │ • Promtail ────┐│              │
│  └─────────────────┘│      └─────────────────┘│              │
│           │         │               │         │              │
│           │ Push    │               │ Push    │              │
│           │ Logs    │               │ Logs    │              │
│           ▼         │               ▼         │              │
│  ┌──────────────────┴───────────────┴──────────────────┐    │
│  │           CoreSrv (Dell Server - SPoG)              │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ • Traefik (Reverse Proxy + SSL)                     │    │
│  │ • Authelia (Authentication)                          │    │
│  │ • Loki (Centralized Log Aggregation) ◄───┐          │    │
│  │ • Grafana (Visualization) ◄──────────────┤          │    │
│  │ • Prometheus (Metrics Collection)         │          │    │
│  └───────────────────────────────────────────┼──────────┘    │
│                                               │               │
│                                          ┌────┴─────┐         │
│                                          │   User   │         │
│                                          │ Workstation│       │
│                                          └──────────┘         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Key**: Pis PUSH logs to CoreSrv. CoreSrv never SSH into Pis.

### Two-Pi Architecture

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
- **CoreSrv component**: See [Orion-Sentinel-CoreSrv](https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv)
- **DNS component**: See [rpi-ha-dns-stack](https://github.com/yorgosroussakis/rpi-ha-dns-stack)
- **NetSec component**: See [Orion-sentinel-netsec-ai](https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai)

## Acknowledgments

Built for homelabbers and power users who want enterprise-grade network security at home, from simple two-Pi setups to advanced three-node architectures with centralized monitoring.
