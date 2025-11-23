# Configuration Reference - Orion Sentinel Three-Node Architecture

This document describes all configuration variables and settings for the Orion Sentinel three-node deployment.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [CoreSrv Configuration](#coresrv-configuration)
- [Pi #1 (DNS) Configuration](#pi-1-dns-configuration)
- [Pi #2 (NetSec) Configuration](#pi-2-netsec-configuration)
- [Network Configuration](#network-configuration)
- [Promtail Configuration](#promtail-configuration)
- [Environment Variables](#environment-variables)

## Architecture Overview

The three-node architecture follows a **Single Pane of Glass (SPoG)** design:

- **CoreSrv**: Central observability stack (Loki + Grafana + Prometheus)
- **Pi #1**: DNS stack with Promtail agent
- **Pi #2**: NetSec stack with Promtail agent

**Key Principle**: Pis NEVER scrape or pull metrics. They always PUSH logs and metrics to CoreSrv.

## CoreSrv Configuration

### Location

- **Repository**: `/opt/Orion-Sentinel-CoreSrv`
- **Data Root**: `/srv/orion-sentinel-core/`
- **Environment Files**: `/opt/Orion-Sentinel-CoreSrv/env/`

### Environment Files

#### `env/.env.core`

Controls Traefik and Authelia configuration.

```bash
# Traefik Configuration
TRAEFIK_DOMAIN=local                    # Domain for Traefik services
TRAEFIK_ACME_EMAIL=admin@example.com    # Email for Let's Encrypt (if using)

# Authelia Secrets (REQUIRED - generate with: openssl rand -base64 32)
AUTHELIA_JWT_SECRET=<generate-me>
AUTHELIA_SESSION_SECRET=<generate-me>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<generate-me>

# Authelia Configuration
AUTHELIA_DEFAULT_REDIRECTION_URL=https://grafana.local
```

**How to generate secrets:**

```bash
openssl rand -base64 32
```

#### `env/.env.monitoring`

Controls Loki, Grafana, and Prometheus configuration.

```bash
# Data Storage
MONITORING_ROOT=/srv/orion-sentinel-core/monitoring

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<set-secure-password>
GRAFANA_INSTALL_PLUGINS=  # Optional: comma-separated list of plugins

# Loki
LOKI_RETENTION_PERIOD=720h  # 30 days

# Prometheus
PROMETHEUS_RETENTION=30d
```

### Directory Structure

```
/srv/orion-sentinel-core/
├── config/         # Traefik and Authelia configs
├── monitoring/     # Grafana, Loki, Prometheus data
├── cloud/          # Nextcloud data (if enabled)
└── backups/        # Backup storage
```

### Service Endpoints

When running on CoreSrv at `192.168.1.50`:

- **Grafana**: `http://192.168.1.50:3000` or `https://grafana.local`
- **Traefik Dashboard**: `https://traefik.local`
- **Loki API**: `http://192.168.1.50:3100`
- **Prometheus**: `http://192.168.1.50:9090`
- **Authelia**: `https://auth.local`

### Important Notes

- **Loki Push Endpoint**: `http://<coresrv-ip>:3100/loki/api/v1/push`
  - This is where Promtail agents on Pis send logs
- **Prometheus Targets**: Must be configured to scrape Pi exporters (if used)
- **No SSH Scraping**: CoreSrv never SSHs into Pis to pull data

## Pi #1 (DNS) Configuration

### Location

- **Repository**: `/opt/rpi-ha-dns-stack`
- **Environment File**: `/opt/rpi-ha-dns-stack/.env`

### Key Configuration Variables

```bash
# Pi Network Configuration
PI_IP=192.168.1.10              # This Pi's static IP
KEEPALIVED_VIRTUAL_IP=192.168.1.100  # Virtual IP for HA (optional)

# Keepalived HA Configuration (if using multiple Pis)
KEEPALIVED_STATE=MASTER         # MASTER or BACKUP
KEEPALIVED_PRIORITY=100         # Higher = primary (e.g., 100 on MASTER, 90 on BACKUP)
KEEPALIVED_ROUTER_ID=51         # Must be unique on network

# Pi-hole Configuration
PIHOLE_PASSWORD=<set-secure-password>
PIHOLE_DNS1=1.1.1.1             # Upstream DNS
PIHOLE_DNS2=1.0.0.1

# Unbound Configuration
UNBOUND_ENABLE=true             # Enable Unbound recursive DNS
```

### Promtail Configuration

Promtail on Pi #1 is configured automatically by the bootstrap script.

**Configuration File**: `/opt/promtail/promtail-config.yml`

```yaml
clients:
  - url: http://<coresrv-ip>:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: pi-dns
```

**Critical Label**: `host: pi-dns` - This identifies logs from Pi #1 in Loki.

### Service Endpoints

When running on Pi #1 at `192.168.1.10`:

- **Pi-hole Admin**: `http://192.168.1.10/admin`
- **DNS Server**: `192.168.1.10:53` (or VIP if HA configured)

### Important Notes

- **NO local Grafana/Loki**: Pi #1 does not run its own observability stack
- **Promtail only**: Logs are pushed to CoreSrv, not pulled
- **HA Mode**: If using Keepalived, configure VIP and priorities on both Pis
- **Router Configuration**: Set router DNS to Pi IP or VIP

## Pi #2 (NetSec) Configuration

### Location

- **Repository**: `/opt/Orion-sentinel-netsec-ai`
- **Environment File**: `/opt/Orion-sentinel-netsec-ai/.env`

### Key Configuration Variables

```bash
# SPoG Configuration (REQUIRED)
LOKI_URL=http://<coresrv-ip>:3100       # CoreSrv Loki endpoint
LOCAL_OBSERVABILITY=false                # Disable local Grafana/Loki

# NSM Configuration
NSM_INTERFACE=eth0                       # Network interface to monitor
NSM_HOME_NET=192.168.1.0/24             # Your home network CIDR

# Suricata Configuration
SURICATA_RULE_UPDATE=true                # Auto-update IDS rules

# AI Configuration
AI_MODEL=default                         # AI model to use
AI_THRESHOLD=0.7                         # Detection confidence threshold
```

### Stack Configuration

NetSec may be deployed with multiple docker-compose stacks:

1. **NSM Stack**: `/opt/Orion-sentinel-netsec-ai/stacks/nsm/docker-compose.yml`
2. **AI Stack**: `/opt/Orion-sentinel-netsec-ai/stacks/ai/docker-compose.yml`

Or a single compose file:

3. **Root**: `/opt/Orion-sentinel-netsec-ai/docker-compose.yml`

### Promtail Configuration

If NetSec includes Promtail (check repo structure), it should be configured with:

```yaml
clients:
  - url: http://<coresrv-ip>:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: pi-netsec
```

**Critical Label**: `host: pi-netsec` - This identifies logs from Pi #2 in Loki.

### Service Endpoints

When running on Pi #2 at `192.168.1.11`:

- **NSM UI** (if available): `http://192.168.1.11:8081`
- **AI API** (if available): `http://192.168.1.11:5000`

### Important Notes

- **SPoG Mode**: `LOCAL_OBSERVABILITY=false` is critical
- **Loki URL**: Must point to CoreSrv, not localhost
- **Port Mirroring**: Connect Pi #2 to a mirrored/SPAN port for full traffic visibility
- **NO local Grafana**: All visualization happens on CoreSrv

## Network Configuration

### Static IP Addresses

All three nodes should have static IPs or DHCP reservations:

| Node | Recommended IP | Purpose |
|------|---------------|---------|
| CoreSrv | 192.168.1.50 | Central SPoG |
| Pi #1 (DNS) | 192.168.1.10 | DNS server |
| Pi #2 (NetSec) | 192.168.1.11 | Network security |

### Port Requirements

#### CoreSrv

| Port | Service | Access |
|------|---------|--------|
| 3000 | Grafana | Web UI |
| 3100 | Loki | Push API (from Pis) |
| 9090 | Prometheus | Web UI |
| 80/443 | Traefik | HTTP/HTTPS |

#### Pi #1 (DNS)

| Port | Service | Access |
|------|---------|--------|
| 53 | DNS | UDP/TCP from network |
| 80 | Pi-hole Admin | Web UI |
| 9080 | Promtail | Metrics (optional) |

#### Pi #2 (NetSec)

| Port | Service | Access |
|------|---------|--------|
| 8081 | NSM UI | Web UI (if enabled) |
| 5000 | AI API | API (if enabled) |

### Firewall Rules

- **CoreSrv → Pis**: No inbound connections needed (Pis push to CoreSrv)
- **Pis → CoreSrv**: Allow outbound to Loki (port 3100)
- **Workstation → CoreSrv**: Allow access to Grafana (3000), Traefik (80/443)
- **Network → Pi #1**: Allow DNS queries (port 53)

### DNS Configuration

For Traefik hostnames to work:

1. **Option A**: Add to `/etc/hosts` on your workstation:
   ```
   192.168.1.50   grafana.local traefik.local auth.local
   192.168.1.10   dns.local
   192.168.1.11   security.local
   ```

2. **Option B**: Add DNS records in Pi-hole:
   - Local DNS Records → Add entries for `*.local` domains

## Promtail Configuration

### Overview

Promtail is deployed on both Pis to push Docker container logs to CoreSrv Loki.

### Common Configuration

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://<coresrv-ip>:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: <pi-hostname>  # pi-dns or pi-netsec
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
      - labels:
          stream:
      - output:
          source: output
```

### Critical Labels

- `host: pi-dns` - Identifies logs from Pi #1
- `host: pi-netsec` - Identifies logs from Pi #2
- `job: docker` - Identifies Docker container logs

### Querying in Grafana

```promql
# All logs from Pi #1
{host="pi-dns"}

# All logs from Pi #2
{host="pi-netsec"}

# Pi-hole logs specifically
{host="pi-dns", container_name=~".*pihole.*"}

# Suricata logs
{host="pi-netsec"} |= "suricata"

# Error logs from all Pis
{host=~"pi-.*"} |= "error"
```

### Volume Mounts

Promtail container requires:

```yaml
volumes:
  - /opt/promtail/promtail-config.yml:/etc/promtail/config.yml:ro
  - /var/lib/docker/containers:/var/lib/docker/containers:ro
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

## Environment Variables

### Bootstrap Script Variables

These can be set when running the bootstrap scripts:

#### `bootstrap-coresrv.sh`

```bash
CORESRV_REPO_URL=https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv.git
CORESRV_REPO_BRANCH=main
CORESRV_REPO_DIR=/opt/Orion-Sentinel-CoreSrv
ORION_DATA_ROOT=/srv/orion-sentinel-core
```

#### `bootstrap-pi1-dns.sh`

```bash
DNS_REPO_URL=https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
DNS_REPO_BRANCH=main
DNS_REPO_DIR=/opt/rpi-ha-dns-stack
```

#### `bootstrap-pi2-netsec.sh`

```bash
NETSEC_REPO_URL=https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai.git
NETSEC_REPO_BRANCH=main
NETSEC_REPO_DIR=/opt/Orion-sentinel-netsec-ai
```

### Command-Line Arguments

#### `deploy-orion-sentinel.sh`

```bash
--coresrv <ip>         # CoreSrv IP address (required)
--pi-dns <host>        # Pi #1 hostname or IP (required)
--pi-netsec <host>     # Pi #2 hostname or IP (required)
--skip-coresrv         # Skip CoreSrv setup (optional)
```

Example:
```bash
./scripts/deploy-orion-sentinel.sh \
  --coresrv 192.168.1.50 \
  --pi-dns pi1.local \
  --pi-netsec pi2.local
```

## Best Practices

### Security

1. **Change Default Passwords**: Always change Grafana and Pi-hole default passwords
2. **Use Strong Secrets**: Generate Authelia secrets with `openssl rand -base64 32`
3. **Enable HTTPS**: Configure Traefik with Let's Encrypt for production
4. **Firewall Rules**: Limit access to management interfaces

### Monitoring

1. **Label Consistency**: Always use consistent `host` labels in Promtail
2. **Retention Policies**: Configure appropriate retention in Loki (default 30 days)
3. **Disk Space**: Monitor disk usage on CoreSrv (`/srv/orion-sentinel-core/monitoring`)
4. **Alerting**: Set up Grafana alerts for critical events

### Maintenance

1. **Backup Configs**: Regularly backup `.env` files and Grafana dashboards
2. **Update Images**: Keep Docker images up to date
3. **Log Rotation**: Ensure Docker log rotation is configured
4. **Health Checks**: Monitor service health via Grafana dashboards

## Troubleshooting

### Logs Not Appearing in Loki

1. Check Promtail logs: `docker logs promtail`
2. Verify Loki URL is correct in Promtail config
3. Test connectivity: `curl http://<coresrv-ip>:3100/ready`
4. Check `host` label is set correctly

### DNS Not Working

1. Verify Pi-hole is running: `docker ps` on Pi #1
2. Check Pi-hole logs: `docker logs pihole`
3. Test DNS resolution: `nslookup google.com <pi1-ip>`
4. Verify router is using Pi as DNS server

### NetSec Not Seeing Traffic

1. Verify port mirroring is configured on switch
2. Check `NSM_INTERFACE` in `.env` is correct
3. Check Suricata logs: `docker logs suricata`
4. Verify Pi #2 is connected to mirrored port

## Reference Summary

| Component | Location | Config File | Key Variables |
|-----------|----------|-------------|---------------|
| CoreSrv | `/opt/Orion-Sentinel-CoreSrv` | `env/.env.core`, `env/.env.monitoring` | `CORESRV_IP`, `LOKI_URL` |
| Pi #1 DNS | `/opt/rpi-ha-dns-stack` | `.env` | `PI_IP`, `KEEPALIVED_VIRTUAL_IP` |
| Pi #2 NetSec | `/opt/Orion-sentinel-netsec-ai` | `.env` | `LOKI_URL`, `LOCAL_OBSERVABILITY` |
| Promtail (Pi #1) | `/opt/promtail` | `promtail-config.yml` | `clients.url`, `host: pi-dns` |
| Promtail (Pi #2) | `/opt/promtail` | `promtail-config.yml` | `clients.url`, `host: pi-netsec` |

---

For more information, see [GETTING-STARTED-THREE-NODE.md](./GETTING-STARTED-THREE-NODE.md).
