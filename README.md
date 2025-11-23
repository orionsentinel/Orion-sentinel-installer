# Orion Sentinel Installer

A unified installer for deploying the **Orion Sentinel** home network security and privacy suite across three nodes: a Dell server (CoreSrv) and two Raspberry Pis.

## Overview

Orion Sentinel is a comprehensive home network security solution using a **Single Pane of Glass (SPoG)** architecture:

- **CoreSrv (Dell/Server)**: Central observability platform running Traefik, Authelia, Prometheus, Loki, and Grafana
- **Pi #1 (DNS)**: Ad-blocking and DNS filtering via Pi-hole + Unbound with optional high availability
- **Pi #2 (NetSec)**: Network security monitoring, intrusion detection, and AI-powered threat analysis

All logs and metrics from both Pis are forwarded to CoreSrv for centralized monitoring and visualization.

This installer repository provides simple bootstrap scripts to deploy the complete three-node stack with minimal effort.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Home Network                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │       CoreSrv (Dell) - Single Pane of Glass        │    │
│  │  • Traefik • Authelia • Prometheus • Loki • Grafana│    │
│  └────────────────────────────────────────────────────┘    │
│                     ▲              ▲                         │
│            Logs & Metrics    Logs & Metrics                 │
│                     │              │                         │
│  ┌──────────────────┴──┐    ┌─────┴──────────────┐         │
│  │  Pi #1 (DNS)        │    │  Pi #2 (NetSec)    │         │
│  │ • Pi-hole           │    │ • Suricata IDS     │         │
│  │ • Unbound DNS       │    │ • AI Detection     │         │
│  │ • Promtail Agent    │    │ • Promtail Agent   │         │
│  └─────────────────────┘    └────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## Requirements

### Hardware

- **1× Dell Server or PC** (CoreSrv)
  - 8GB+ RAM recommended
  - 100GB+ storage
  - Linux (Debian/Ubuntu recommended)

- **2× Raspberry Pi 4 or 5** (4GB+ RAM recommended)
  - Pi #1: DNS HA node
  - Pi #2: NetSec node

### Software

- **Fresh Linux installations** on all three machines
- **SSH access** configured on both Pis
- **Internet connection** during installation
- **Git** installed on all machines

### Network Setup

- All three machines on the same network
- Static IP addresses or DHCP reservations recommended
- For Pi #2: Network switch with port mirroring/SPAN capability (optional but recommended)

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

#### Step 1: Bootstrap CoreSrv

Run on the Dell/CoreSrv machine:

#### Step 1: Bootstrap CoreSrv

Run on the Dell/CoreSrv machine:

```bash
git clone https://github.com/yorgosroussakis/orion-sentinel-installer.git
cd orion-sentinel-installer
./scripts/bootstrap-coresrv.sh
```

Then configure environment files:

```bash
cd /opt/Orion-Sentinel-CoreSrv/env
nano .env.core        # Set Authelia secrets
nano .env.monitoring  # Set Grafana credentials

# Start CoreSrv services
cd /opt/Orion-Sentinel-CoreSrv
./orionctl.sh up-core
./orionctl.sh up-observability
```

#### Pi #2: Security & Monitoring Setup

Run from your laptop or CoreSrv:

```bash
cd orion-sentinel-installer

export PI_DNS_HOST="192.168.1.100"  # Your Pi #1 IP
export CORESRV_IP="192.168.1.10"    # Your CoreSrv IP

./scripts/bootstrap-pi1-dns.sh
```

#### Step 3: Bootstrap Pi #2 (NetSec)

Run from your laptop or CoreSrv:

```bash
export PI_NETSEC_HOST="192.168.1.101"  # Your Pi #2 IP
export CORESRV_IP="192.168.1.10"       # Your CoreSrv IP

./scripts/bootstrap-pi2-netsec.sh
```

## What Gets Installed

### CoreSrv (Dell/Server)

The bootstrap script will:
- ✅ Install Docker CE and Docker Compose
- ✅ Clone the [Orion-Sentinel-CoreSrv](https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv) repository
- ✅ Create directory structure under `/srv/orion-sentinel-core`
- ✅ Generate environment file templates
- ✅ Set up Traefik (reverse proxy)
- ✅ Set up Authelia (authentication)
- ✅ Set up Prometheus (metrics)
- ✅ Set up Loki (log aggregation)
- ✅ Set up Grafana (visualization)

**Installation location**: `/opt/Orion-Sentinel-CoreSrv`

### Pi #1 (DNS & Privacy)

The bootstrap script will:
- ✅ Install Docker CE and Docker Compose (remote or local)
- ✅ Clone the [rpi-ha-dns-stack](https://github.com/yorgosroussakis/rpi-ha-dns-stack) repository
- ✅ Set up Pi-hole for network-wide ad blocking
- ✅ Set up Unbound for recursive DNS
- ✅ Configure optional high availability with Keepalived
- ✅ Deploy Promtail agent to forward logs to CoreSrv Loki

**Installation location**: `/opt/rpi-ha-dns-stack`

### Pi #2 (Security & Monitoring)

The bootstrap script will:
- ✅ Install Docker CE and Docker Compose (remote or local)
- ✅ Clone the [Orion-sentinel-netsec-ai](https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai) repository
- ✅ Configure `.env` for SPoG mode (logs → CoreSrv)
- ✅ Set up network monitoring with Suricata
- ✅ Deploy AI-powered threat detection
- ✅ Forward logs and metrics to CoreSrv

**Installation location**: `/opt/Orion-sentinel-netsec-ai`

## Validation

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

### Single Pane of Glass (SPoG)

- **Centralized Monitoring**: All logs and metrics aggregated on CoreSrv
- **No SSH Scraping**: Pis push data to CoreSrv via Promtail agents
- **Unified Dashboards**: All services visible in single Grafana instance
- **Secure Access**: Traefik + Authelia provide authentication and SSL

### Security Best Practices

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

Built for homelabbers and power users who want enterprise-grade network security at home with centralized observability.
