# Orion Sentinel Installer

A unified installer for deploying the **Orion Sentinel** home network security and privacy suite across multiple architectures.

## Overview

Orion Sentinel is a comprehensive home network security solution that supports two deployment architectures:

### Two-Pi Architecture (Original)

- **CoreSrv (Dell/Server)**: Central observability platform running Traefik, Authelia, Prometheus, Loki, and Grafana
- **Pi #1 (DNS)**: Ad-blocking and DNS filtering via Pi-hole + Unbound with optional high availability
- **Pi #2 (NetSec)**: Network security monitoring, intrusion detection, and AI-powered threat analysis

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

- **Fresh Linux installations** on all three machines
- **SSH access** configured on both Pis
- **Internet connection** during installation
- **Git** installed on all machines

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

### Two-Pi Architecture (Standalone) - Simple Setup

**Best for**: Users without a dedicated server, want self-contained Pis

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

3. **Run the orchestrator script**

   ```bash
   ./scripts/orchestrate-install.sh --pi1 pi1.local --pi2 pi2.local
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
- ✅ Set up Unbound for recursive DNS
- ✅ Configure optional high availability with Keepalived
- ✅ Deploy Promtail agent to forward logs to CoreSrv Loki

**Installation location**: `/opt/rpi-ha-dns-stack`

#### Pi #2 (Security & Monitoring)

The bootstrap script will:
- ✅ Install Docker CE and Docker Compose
- ✅ Clone the NSM repository
- ✅ Run the NSM installation script
- ✅ Set up network monitoring with Suricata
- ✅ Deploy AI-powered threat detection
- ✅ Forward logs and metrics to CoreSrv

**Installation location**: `/opt/Orion-sentinel-netsec-ai`

## Documentation

### Three-Node Architecture (CoreSrv + 2 Pis)
- 📘 **[Getting Started Guide](docs/GETTING-STARTED-THREE-NODE.md)** - Complete setup walkthrough
- 📗 **[Configuration Reference](docs/CONFIG-REFERENCE.md)** - All configuration variables and settings
- 🏗️ **Architecture**: CoreSrv (SPoG) + DNS Pi + NetSec Pi

### Two-Pi Architecture (Standalone)
- 📙 **[Getting Started with Two Pis](docs/getting-started-two-pi.md)** - Original two-Pi setup guide

### Component Repositories
- [Orion-Sentinel-CoreSrv](https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv) - Central SPoG (Traefik, Loki, Grafana, Prometheus)
- [rpi-ha-dns-stack](https://github.com/yorgosroussakis/rpi-ha-dns-stack) - DNS HA component (Pi-hole + Unbound)
- [Orion-sentinel-netsec-ai](https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai) - NetSec component (NSM + AI)

## Post-Installation

After deployment, verify everything is working:

### 1. Check CoreSrv Services

```bash
ssh user@coresrv-ip
cd /opt/Orion-Sentinel-CoreSrv
./orionctl.sh status
```

### 2. Access Grafana

Open your browser and navigate to:
```
http://CORESRV_IP:3000
```

Login with credentials from `.env.monitoring`.

### 3. Verify Logs in Loki

In Grafana, navigate to **Explore** → **Loki** and run:
- `{host="pi-dns"}` - Should show DNS Pi logs
- `{host="pi-netsec"}` - Should show NetSec Pi logs

### 4. Test DNS Filtering

- Access Pi-hole: `http://PI_DNS_IP/admin`
- Configure router to use Pi #1 as DNS server
- Test ad blocking on client devices

## Post-Installation

After successful installation:

1. **Configure your router**: Set DNS server to Pi #1's IP address
2. **Set up port mirroring**: Connect Pi #2 to a switch mirror/SPAN port for traffic monitoring
3. **Review Grafana dashboards**: Check pre-configured dashboards for DNS and NetSec
4. **Customize blocklists**: Add custom blocklists in Pi-hole
5. **Fine-tune detection**: Adjust Suricata rules and AI thresholds

## Documentation

For detailed setup instructions and configuration:

- **[Getting Started (Three-Node)](docs/GETTING-STARTED-THREE-NODE.md)** - Complete deployment guide
- **[Configuration Reference](docs/CONFIG-REFERENCE.md)** - All configuration parameters
- **[Scripts Reference](scripts/README.md)** - Bootstrap script usage
- **[Two-Pi Setup](docs/getting-started-two-pi.md)** - Legacy two-Pi deployment (deprecated)

For component-specific documentation:
- [Orion-Sentinel-CoreSrv](https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv)
- [rpi-ha-dns-stack](https://github.com/yorgosroussakis/rpi-ha-dns-stack)
- [Orion-sentinel-netsec-ai](https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai)

## Advanced Configuration

### High Availability DNS

To add a second DNS Pi for HA, run the DNS bootstrap script on a second Pi and configure Keepalived virtual IP in the `.env` files. See [CONFIG-REFERENCE.md](docs/CONFIG-REFERENCE.md) for details.

### Traefik Dynamic Configuration

Expose Pi services via Traefik on CoreSrv by creating dynamic config files. See [GETTING-STARTED-THREE-NODE.md](docs/GETTING-STARTED-THREE-NODE.md) for examples.

### Custom Promtail Configuration

Promtail is automatically configured during bootstrap. To customize, edit `/etc/promtail/promtail-config.yml` on each Pi.

## Troubleshooting

### Logs Not Appearing in Loki

1. Check Promtail is running: `docker ps | grep promtail`
2. Check Promtail logs: `docker logs promtail`
3. Verify CoreSrv Loki is accessible: `curl http://CORESRV_IP:3100/ready`
4. Check firewall: `sudo ufw allow 3100/tcp`

### Docker Permission Issues

```bash
sudo usermod -aG docker $USER
# Log out and back in, or:
newgrp docker
```

### Services Not Starting

Check logs:
```bash
cd /opt/Orion-Sentinel-CoreSrv  # or component directory
docker compose logs
# or
./orionctl.sh logs
```

For more troubleshooting, see [GETTING-STARTED-THREE-NODE.md](docs/GETTING-STARTED-THREE-NODE.md).

## Architecture Highlights

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

- All secrets generated with strong random values
- Authelia provides authentication layer
- Traefik handles SSL/TLS termination
- Pi-hole blocks malicious domains
- Suricata detects network threats
- AI-powered anomaly detection

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
