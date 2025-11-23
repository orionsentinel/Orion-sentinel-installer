# Getting Started with Orion Sentinel - Three-Node Architecture

This guide walks you through deploying Orion Sentinel in a three-node architecture with a central Single Pane of Glass (SPoG) on CoreSrv.

## Architecture Overview

The three-node Orion Sentinel deployment consists of:

```
┌──────────────────────────────────────────────────────────────┐
│                    Orion Sentinel Architecture               │
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
│           │ Logs    │               │ Logs    │              │
│           ▼         │               ▼         │              │
│  ┌──────────────────┴───────────────┴──────────────────┐    │
│  │           CoreSrv (Dell Server - SPoG)              │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ • Traefik (Reverse Proxy + SSL)                     │    │
│  │ • Authelia (Authentication)                          │    │
│  │ • Loki (Centralized Log Aggregation)                │    │
│  │ • Grafana (Visualization)                           │    │
│  │ • Prometheus (Metrics Collection)                   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **CoreSrv** is the central Single Pane of Glass (SPoG)
   - All monitoring, logging, and visualization happens here
   - Runs Loki to collect logs from both Pis
   - Runs Grafana for visualization
   - Runs Prometheus for metrics (optional)
   - Runs Traefik for reverse proxy and SSL termination

2. **Pi #1** is dedicated to DNS
   - Runs Pi-hole for ad-blocking
   - Runs Unbound for recursive DNS
   - Runs Promtail to send logs to CoreSrv Loki
   - Does NOT run local Grafana/Loki

3. **Pi #2** is dedicated to Network Security
   - Runs Suricata for IDS/IPS
   - Runs AI-powered threat detection
   - Configured in SPoG mode: `LOCAL_OBSERVABILITY=false`
   - Sends all logs to CoreSrv via `LOKI_URL`

## Prerequisites

### Hardware

- **1× Dell Server** or similar x86 machine for CoreSrv (16GB+ RAM recommended)
- **2× Raspberry Pi 5** (8GB RAM recommended)
- **Network switch** with port mirroring capability (for Pi #2)
- **Static IP addresses** or DHCP reservations for all three nodes

### Software

- **Raspberry Pi OS 64-bit** (Bookworm or later) on both Pis
- **Ubuntu Server** or **Debian** on CoreSrv
- **SSH access** to all three machines
- **Git** installed on all machines

### Network

- All three nodes on the same network
- SSH access from your workstation to all nodes
- Internet connectivity for package downloads

## Installation Steps

### Step 1: Prepare CoreSrv (Dell Server)

1. **SSH into your CoreSrv:**

   ```bash
   ssh user@<coresrv-ip>
   ```

2. **Clone the installer repository:**

   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git
   cd Orion-sentinel-installer
   ```

3. **Run the CoreSrv bootstrap script:**

   ```bash
   ./scripts/bootstrap-coresrv.sh
   ```

   This will:
   - Install Docker CE
   - Clone the Orion-Sentinel-CoreSrv repository to `/opt/Orion-Sentinel-CoreSrv`
   - Create data directories under `/srv/orion-sentinel-core/`
   - Generate environment files from examples
   - Optionally start Traefik, Authelia, Loki, Grafana, and Prometheus

4. **Configure environment files:**

   Edit the generated `.env` files:

   ```bash
   cd /opt/Orion-Sentinel-CoreSrv
   nano env/.env.core
   nano env/.env.monitoring
   ```

   Fill in required values:
   - `AUTHELIA_JWT_SECRET` (generate with `openssl rand -base64 32`)
   - `AUTHELIA_SESSION_SECRET` (generate with `openssl rand -base64 32`)
   - `AUTHELIA_STORAGE_ENCRYPTION_KEY` (generate with `openssl rand -base64 32`)
   - `GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD`
   - `MONITORING_ROOT=/srv/orion-sentinel-core/monitoring`

5. **Start the CoreSrv services:**

   ```bash
   cd /opt/Orion-Sentinel-CoreSrv
   ./orionctl.sh up-core           # Start Traefik + Authelia
   ./orionctl.sh up-observability  # Start Loki + Grafana + Prometheus
   ```

6. **Verify CoreSrv is running:**

   ```bash
   docker ps
   ```

   You should see containers for:
   - Traefik
   - Authelia
   - Loki
   - Grafana
   - Prometheus

7. **Access Grafana:**

   Open a browser and navigate to:
   - `http://<coresrv-ip>:3000`
   - Login with the credentials you set in `.env.monitoring`

### Step 2: Bootstrap Pi #1 (DNS)

You can run this either **from your workstation** (remote mode) or **directly on Pi #1** (local mode).

#### Option A: Remote Mode (from your workstation)

1. **On your workstation, clone the installer:**

   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git
   cd Orion-sentinel-installer
   ```

2. **Run the Pi #1 bootstrap script remotely:**

   ```bash
   ./scripts/bootstrap-pi1-dns.sh \
     --host <pi1-hostname-or-ip> \
     --coresrv <coresrv-ip>
   ```

   Example:
   ```bash
   ./scripts/bootstrap-pi1-dns.sh --host pi-dns.local --coresrv 192.168.1.50
   ```

#### Option B: Local Mode (on Pi #1 itself)

1. **SSH into Pi #1:**

   ```bash
   ssh pi@<pi1-ip>
   ```

2. **Clone the installer repository:**

   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git
   cd Orion-sentinel-installer
   ```

3. **Run the bootstrap script:**

   ```bash
   ./scripts/bootstrap-pi1-dns.sh --coresrv <coresrv-ip>
   ```

   Example:
   ```bash
   ./scripts/bootstrap-pi1-dns.sh --coresrv 192.168.1.50
   ```

#### What This Does

- Installs Docker CE on Pi #1
- Clones the DNS repository to `/opt/rpi-ha-dns-stack`
- Generates `.env` configuration
- Starts Pi-hole and Unbound containers
- Deploys Promtail configured to send logs to CoreSrv Loki

### Step 3: Bootstrap Pi #2 (NetSec)

Similar to Pi #1, you can run this remotely or locally.

#### Option A: Remote Mode (from your workstation)

```bash
./scripts/bootstrap-pi2-netsec.sh \
  --host <pi2-hostname-or-ip> \
  --coresrv <coresrv-ip>
```

Example:
```bash
./scripts/bootstrap-pi2-netsec.sh --host pi-netsec.local --coresrv 192.168.1.50
```

#### Option B: Local Mode (on Pi #2 itself)

1. **SSH into Pi #2:**

   ```bash
   ssh pi@<pi2-ip>
   ```

2. **Clone the installer repository:**

   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-installer.git
   cd Orion-sentinel-installer
   ```

3. **Run the bootstrap script:**

   ```bash
   ./scripts/bootstrap-pi2-netsec.sh --coresrv <coresrv-ip>
   ```

#### What This Does

- Installs Docker CE on Pi #2
- Clones the NetSec repository to `/opt/Orion-sentinel-netsec-ai`
- Generates `.env` with SPoG configuration:
  - `LOKI_URL=http://<coresrv-ip>:3100`
  - `LOCAL_OBSERVABILITY=false`
- Starts NSM stack (Suricata, etc.)
- Starts AI stack

### Step 4: Full Orchestration (Optional)

For an automated deployment of all components, use the full orchestrator:

```bash
./scripts/deploy-orion-sentinel.sh \
  --coresrv <coresrv-ip> \
  --pi-dns <pi1-hostname> \
  --pi-netsec <pi2-hostname>
```

Example:
```bash
./scripts/deploy-orion-sentinel.sh \
  --coresrv 192.168.1.50 \
  --pi-dns pi1.local \
  --pi-netsec pi2.local
```

Use `--skip-coresrv` if you've already set up CoreSrv manually.

## Verification

### 1. Check Services on CoreSrv

```bash
ssh user@<coresrv-ip>
cd /opt/Orion-Sentinel-CoreSrv
docker ps
```

You should see:
- `traefik`
- `authelia`
- `loki`
- `grafana`
- `prometheus` (if enabled)

### 2. Verify Logs in Grafana

1. Access Grafana: `http://<coresrv-ip>:3000`
2. Go to **Explore** → Select **Loki** as data source
3. Query for Pi #1 logs: `{host="pi-dns"}`
4. Query for Pi #2 logs: `{host="pi-netsec"}`

You should see logs streaming from both Pis.

### 3. Test DNS Filtering

1. Configure a test device to use Pi #1 as DNS server
2. Visit a website with ads
3. Verify ads are blocked
4. Check Pi-hole admin: `http://<pi1-ip>/admin`

### 4. Verify Network Monitoring

1. Ensure Pi #2 is connected to a mirrored/SPAN port
2. Check Grafana dashboards for network traffic
3. Look for Suricata alerts in Loki logs: `{host="pi-netsec"} |= "suricata"`

## Advanced Configuration

### Configure Traefik Routes

To access services via friendly hostnames (e.g., `https://dns.local`):

1. On CoreSrv, add Traefik dynamic configuration in `/opt/Orion-Sentinel-CoreSrv/config/traefik/dynamic/`
2. Create route files for Pi services
3. Add DNS records or `/etc/hosts` entries on your workstation

Example `/etc/hosts` entry:
```
192.168.1.50   grafana.local traefik.local auth.local
192.168.1.10   dns.local
192.168.1.11   security.local
```

### Set Up High Availability DNS

To configure DNS HA with Keepalived:

1. Set up a second Pi with the DNS bootstrap script
2. Edit `.env` on both Pis:
   ```bash
   ssh pi@<pi1-ip>
   nano /opt/rpi-ha-dns-stack/.env
   ```
3. Configure:
   - `KEEPALIVED_VIRTUAL_IP` (a free IP on your network)
   - `KEEPALIVED_PRIORITY` (100 on primary, 90 on backup)
   - `KEEPALIVED_STATE` (MASTER on primary, BACKUP on backup)
4. Restart services on both Pis
5. Update router DNS to use the Virtual IP

### Customize NetSec Monitoring

Edit `/opt/Orion-sentinel-netsec-ai/.env` on Pi #2:

```bash
NSM_INTERFACE=eth0  # or your mirrored interface
LOKI_URL=http://<coresrv-ip>:3100
LOCAL_OBSERVABILITY=false
```

Restart services:
```bash
cd /opt/Orion-sentinel-netsec-ai
docker compose down
docker compose up -d
```

## Troubleshooting

### Logs Not Appearing in Grafana

1. **Check Promtail on Pis:**
   ```bash
   docker logs promtail
   ```
   Look for connection errors to Loki.

2. **Check Loki on CoreSrv:**
   ```bash
   docker logs loki
   ```

3. **Verify network connectivity:**
   ```bash
   curl http://<coresrv-ip>:3100/ready
   ```

### Docker Permission Errors

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Services Not Starting

Check logs:
```bash
docker compose logs <service-name>
```

Check disk space:
```bash
df -h
```

Check port conflicts:
```bash
sudo netstat -tulpn | grep <port>
```

## Next Steps

1. **Configure Alerts:** Set up Grafana alerts for critical events
2. **Backup Configuration:** Back up `.env` files and Grafana dashboards
3. **Monitor Performance:** Watch CPU, memory, and disk usage
4. **Update Regularly:** Keep Docker images and packages up to date
5. **Explore Dashboards:** Import community Grafana dashboards for Pi-hole, Suricata, etc.

## References

- [Orion-Sentinel-CoreSrv Repository](https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv)
- [rpi-ha-dns-stack Repository](https://github.com/yorgosroussakis/rpi-ha-dns-stack)
- [Orion-sentinel-netsec-ai Repository](https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai)
- [Config Reference](./CONFIG-REFERENCE.md)

---

**Happy monitoring! 🛡️🔒**
