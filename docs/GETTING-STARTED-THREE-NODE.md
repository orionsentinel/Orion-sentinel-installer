# Getting Started with Orion Sentinel on Three Nodes

This guide explains how to deploy the complete Orion Sentinel stack across three nodes: a Dell server (CoreSrv) and two Raspberry Pis.

## Architecture Overview

The three-node Orion Sentinel deployment uses a **Single Pane of Glass (SPoG)** architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                      Your Home Network                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          CoreSrv (Dell) - Single Pane of Glass           │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  • Traefik (reverse proxy)                               │  │
│  │  • Authelia (authentication)                             │  │
│  │  • Prometheus (metrics aggregation)                      │  │
│  │  • Loki (log aggregation)          ┌──────────┐          │  │
│  │  • Grafana (visualization)         │  SPoG    │          │  │
│  │  • Cloud services                  │ (Central)│          │  │
│  └────────────────────────────────────┴──────────┴──────────┘  │
│                     ▲              ▲                             │
│                     │              │                             │
│            Logs & Metrics    Logs & Metrics                     │
│                     │              │                             │
│  ┌──────────────────┴──┐    ┌─────┴──────────────┐             │
│  │  Pi #1 (DNS)        │    │  Pi #2 (NetSec)    │             │
│  ├─────────────────────┤    ├────────────────────┤             │
│  │ • Pi-hole           │    │ • Suricata IDS     │             │
│  │ • Unbound DNS       │    │ • AI Detection     │             │
│  │ • Keepalived (HA)   │    │ • Threat Intel     │             │
│  │ • Promtail Agent    │    │ • Promtail Agent   │             │
│  └─────────────────────┘    └────────────────────┘             │
│           ↑                           ↑                         │
│      DNS Queries              Network Mirror Port               │
└─────────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **CoreSrv is the SPoG**: All monitoring, logging, and visualization happens on CoreSrv
2. **Pis push data to CoreSrv**: Promtail agents on both Pis forward logs to Loki on CoreSrv
3. **No SSH scraping**: CoreSrv never scrapes Pis via SSH; all data is pushed from Pis
4. **Centralized configuration**: Environment files and secrets managed on each node

## Prerequisites

### Hardware

- **1× Dell Server or PC** (CoreSrv)
  - 8GB+ RAM recommended
  - 100GB+ storage
  - Linux (Debian/Ubuntu recommended)
  
- **2× Raspberry Pi 4 or 5** (4GB+ RAM recommended)
  - Pi #1: DNS HA node
  - Pi #2: NetSec node with network monitoring capability

### Software

- **Fresh Linux installations** on all three machines
- **SSH access** configured on both Pis
- **Internet connectivity** during installation
- **Git** installed on all machines

### Network Setup

- All three machines on the same network
- Static IP addresses or DHCP reservations recommended
- For Pi #2: Access to a network switch with port mirroring/SPAN capability (optional but recommended)

## Installation Steps

### Step 1: Bootstrap CoreSrv

Run this on the Dell/CoreSrv machine (or SSH into it first):

```bash
# Clone the installer repository
git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git
cd Orion-sentinel-installer

# Run the CoreSrv bootstrap script
./scripts/bootstrap-coresrv.sh
```

The script will:
- Install Docker and Docker Compose
- Clone the Orion-Sentinel-CoreSrv repository to `/opt/Orion-Sentinel-CoreSrv`
- Create required directory structure under `/srv/orion-sentinel-core`
- Generate environment file templates from examples

**Post-bootstrap configuration:**

```bash
cd /opt/Orion-Sentinel-CoreSrv/env

# Edit .env.core - configure Authelia secrets and domain settings
nano .env.core

# Edit .env.monitoring - configure Grafana credentials
nano .env.monitoring
```

Required configurations in `.env.core`:
- `AUTHELIA_JWT_SECRET` - Generate with `openssl rand -base64 64`
- `AUTHELIA_SESSION_SECRET` - Generate with `openssl rand -base64 64`
- `AUTHELIA_STORAGE_ENCRYPTION_KEY` - Generate with `openssl rand -base64 64`

Required configurations in `.env.monitoring`:
- `GRAFANA_ADMIN_USER` - Your desired admin username
- `GRAFANA_ADMIN_PASSWORD` - Your desired admin password
- `MONITORING_ROOT` - Path for monitoring data (default: `/srv/orion-sentinel-core/monitoring`)

**Bring up the core services:**

```bash
cd /opt/Orion-Sentinel-CoreSrv

# Start core stack (Traefik + Authelia)
./orionctl.sh up-core

# Start monitoring stack (Prometheus + Loki + Grafana)
./orionctl.sh up-observability
```

Verify services are running:
```bash
./orionctl.sh status
```

### Step 2: Bootstrap Pi #1 (DNS)

Run this from your laptop or from CoreSrv. You can also run it directly on Pi #1 by leaving the hostname empty.

```bash
cd Orion-sentinel-installer

# Set environment variables
export PI_DNS_HOST="192.168.1.100"  # Replace with your Pi #1 IP
export CORESRV_IP="192.168.1.10"    # Replace with your CoreSrv IP

# Run the DNS bootstrap script
./scripts/bootstrap-pi1-dns.sh
```

The script will:
- SSH into Pi #1 (if `PI_DNS_HOST` is set)
- Install Docker and Docker Compose
- Clone the rpi-ha-dns-stack repository to `/opt/rpi-ha-dns-stack`
- Configure the DNS stack
- Bring up Pi-hole and Unbound containers
- Deploy Promtail agent configured to send logs to CoreSrv Loki

**Verification:**

1. Access Pi-hole admin interface:
   ```
   http://192.168.1.100/admin
   ```

2. Check Grafana on CoreSrv:
   - Navigate to Loki Explore
   - Query: `{host="pi-dns"}`
   - You should see logs from the DNS Pi

### Step 3: Bootstrap Pi #2 (NetSec)

Run this from your laptop or from CoreSrv:

```bash
cd Orion-sentinel-installer

# Set environment variables
export PI_NETSEC_HOST="192.168.1.101"  # Replace with your Pi #2 IP
export CORESRV_IP="192.168.1.10"       # Replace with your CoreSrv IP

# Run the NetSec bootstrap script
./scripts/bootstrap-pi2-netsec.sh
```

The script will:
- SSH into Pi #2
- Install Docker and Docker Compose
- Clone the Orion-sentinel-netsec-ai repository to `/opt/Orion-sentinel-netsec-ai`
- Configure `.env` file with `LOKI_URL=http://CORESRV_IP:3100` and `LOCAL_OBSERVABILITY=false`
- Bring up NSM stack (`stacks/nsm`)
- Bring up AI stack (`stacks/ai`)

**Verification:**

1. Check Grafana on CoreSrv:
   - Navigate to Loki Explore
   - Query: `{host="pi-netsec"}`
   - You should see logs from the NetSec Pi

2. Verify containers on Pi #2:
   ```bash
   ssh pi@192.168.1.101
   docker ps
   ```

### Step 4: Full Stack Deployment (Alternative)

Instead of running Steps 1-3 individually, you can use the orchestration script:

```bash
cd Orion-sentinel-installer

# Run the full deployment orchestrator
./scripts/deploy-orion-sentinel.sh
```

This interactive script will:
- Prompt for CoreSrv IP, Pi DNS host, and Pi NetSec host
- Optionally bootstrap CoreSrv (if you confirm)
- Bootstrap both Pis in sequence
- Provide a comprehensive deployment checklist

### Step 5: Validate Deployment

#### Check CoreSrv Services

```bash
ssh user@coresrv-ip
cd /opt/Orion-Sentinel-CoreSrv
./orionctl.sh status
```

All services should show as "Up" or "running".

#### Access Grafana

```
http://CORESRV_IP:3000
# or https://grafana.local (if DNS and Traefik configured)
```

Login with the credentials you set in `.env.monitoring`.

#### Verify Loki Logs

In Grafana:
1. Navigate to **Explore**
2. Select **Loki** as the data source
3. Run queries:
   - `{host="pi-dns"}` - Should show DNS Pi logs
   - `{host="pi-netsec"}` - Should show NetSec Pi logs

#### Verify Prometheus Metrics (if configured)

In Grafana:
1. Navigate to **Explore**
2. Select **Prometheus** as the data source
3. Check for metrics from both Pis (if exporters are configured)

#### Test DNS Filtering

1. Configure a test device to use Pi #1 as DNS server
2. Visit a website with ads
3. Ads should be blocked
4. Check Pi-hole query log: `http://PI_DNS_IP/admin`

#### Test Network Monitoring

1. Ensure Pi #2 is connected to a switch mirror/SPAN port
2. Generate some network traffic
3. Check Grafana dashboards for network activity
4. Review Suricata alerts (if any)

## Advanced Configuration

### High Availability DNS

To add a second DNS Pi for HA:

1. Bootstrap another Pi using the same DNS bootstrap script
2. Edit `.env` on both DNS Pis:
   ```bash
   KEEPALIVED_VIRTUAL_IP=192.168.1.50
   KEEPALIVED_STATE=MASTER  # on Pi #1
   KEEPALIVED_STATE=BACKUP  # on Pi #2
   KEEPALIVED_PRIORITY=100  # on Pi #1
   KEEPALIVED_PRIORITY=90   # on Pi #2
   ```
3. Restart DNS stacks on both Pis
4. Configure router DNS to use the Virtual IP (192.168.1.50)

### Traefik Dynamic Configuration

To expose Pi services via Traefik on CoreSrv:

1. Create dynamic config files in `/opt/Orion-Sentinel-CoreSrv/config/traefik/dynamic/`
2. Example for DNS Pi:
   ```yaml
   # dns-pi.yml
   http:
     routers:
       dns-admin:
         rule: "Host(`dns.local`)"
         service: dns-admin
         middlewares:
           - authelia
     services:
       dns-admin:
         loadBalancer:
           servers:
             - url: "http://192.168.1.100"
   ```

3. Set up local DNS or `/etc/hosts`:
   ```
   192.168.1.10  dns.local
   192.168.1.10  security.local
   192.168.1.10  grafana.local
   ```

### Custom Promtail Configuration

Promtail configuration is generated during bootstrap. To customize:

**On DNS Pi:**
```bash
ssh pi@pi-dns-ip
sudo nano /etc/promtail/promtail-config.yml
# Make changes
docker restart promtail
```

**On NetSec Pi:**
Promtail configuration should be part of the Orion-sentinel-netsec-ai repository's `.env` file via `LOKI_URL`.

## Maintenance

### Updating Services

**Update CoreSrv:**
```bash
cd /opt/Orion-Sentinel-CoreSrv
git pull
./orionctl.sh restart-all
```

**Update DNS Pi:**
```bash
ssh pi@pi-dns-ip
cd /opt/rpi-ha-dns-stack
git pull
docker compose down && docker compose up -d
```

**Update NetSec Pi:**
```bash
ssh pi@pi-netsec-ip
cd /opt/Orion-sentinel-netsec-ai
git pull
cd stacks/nsm && docker compose down && docker compose up -d
cd ../ai && docker compose down && docker compose up -d
```

### Monitoring Disk Space

Check disk usage on all nodes regularly:
```bash
df -h
docker system df
```

Clean up old Docker resources:
```bash
docker system prune -a --volumes
```

### Log Rotation

Loki on CoreSrv handles log retention. Configure in `.env.monitoring`:
```
LOKI_RETENTION_PERIOD=720h  # 30 days
```

## Troubleshooting

### Logs not appearing in Loki

1. Check Promtail is running on the Pi:
   ```bash
   docker ps | grep promtail
   ```

2. Check Promtail logs:
   ```bash
   docker logs promtail
   ```

3. Verify CoreSrv Loki is accessible:
   ```bash
   curl http://CORESRV_IP:3100/ready
   ```

4. Check firewall on CoreSrv:
   ```bash
   sudo ufw status
   # Allow port 3100 if needed
   sudo ufw allow 3100/tcp
   ```

### Docker permission issues

On any Pi:
```bash
sudo usermod -aG docker $USER
# Log out and back in, or:
newgrp docker
```

### Services not starting on CoreSrv

Check logs:
```bash
cd /opt/Orion-Sentinel-CoreSrv
./orionctl.sh logs
```

Verify environment files:
```bash
cat env/.env.core
cat env/.env.monitoring
```

### DNS not working after Pi #1 setup

1. Verify Pi-hole is running:
   ```bash
   ssh pi@pi-dns-ip
   docker ps | grep pihole
   ```

2. Test DNS resolution from Pi itself:
   ```bash
   nslookup google.com localhost
   ```

3. Check router DNS configuration
4. Clear DNS cache on client devices

## Additional Resources

- **CoreSrv Repository**: [Orion-Sentinel-CoreSrv](https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv)
- **DNS HA Repository**: [rpi-ha-dns-stack](https://github.com/yorgosroussakis/rpi-ha-dns-stack)
- **NetSec Repository**: [Orion-sentinel-netsec-ai](https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai)
- **Configuration Reference**: [CONFIG-REFERENCE.md](CONFIG-REFERENCE.md)

## Getting Help

For issues:
1. Check this guide and the troubleshooting section
2. Review component-specific documentation in their repositories
3. Check existing GitHub issues
4. Open a new issue with detailed error messages and logs

Happy monitoring! 🛡️
