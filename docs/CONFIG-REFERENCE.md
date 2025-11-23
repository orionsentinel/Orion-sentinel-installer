# Configuration Reference

This document provides a comprehensive reference for all configuration values used across the three-node Orion Sentinel deployment.

## Table of Contents

- [Network Configuration](#network-configuration)
- [CoreSrv Configuration](#coresrv-configuration)
- [Pi #1 (DNS) Configuration](#pi-1-dns-configuration)
- [Pi #2 (NetSec) Configuration](#pi-2-netsec-configuration)
- [Promtail Configuration](#promtail-configuration)
- [Environment Variables](#environment-variables)

---

## Network Configuration

### IP Address Planning

Plan your IP addresses before deployment:

| Node | Role | Recommended IP | Notes |
|------|------|---------------|-------|
| CoreSrv | Central SPoG | `192.168.1.10` | Static IP required |
| Pi #1 | DNS HA | `192.168.1.100` | Static IP recommended |
| Pi #2 | NetSec | `192.168.1.101` | Static IP recommended |
| DNS VIP | HA Virtual IP | `192.168.1.50` | Only if using DNS HA with 2+ Pis |

### Required Ports

#### CoreSrv Inbound Ports

| Port | Protocol | Service | Required For |
|------|----------|---------|--------------|
| 80 | TCP | Traefik HTTP | Web services |
| 443 | TCP | Traefik HTTPS | Secure web services |
| 3000 | TCP | Grafana | Direct access (optional) |
| 3100 | TCP | Loki | **Log ingestion from Pis** |
| 9090 | TCP | Prometheus | Direct access (optional) |

**Important**: Port 3100 (Loki) must be accessible from both Pis for log forwarding.

#### Pi #1 (DNS) Inbound Ports

| Port | Protocol | Service | Required For |
|------|----------|---------|--------------|
| 53 | TCP/UDP | DNS | DNS queries from clients |
| 80 | TCP | Pi-hole Web | Admin interface |

#### Pi #2 (NetSec) Inbound Ports

Typically no inbound ports required (depends on NetSec repository configuration).

---

## CoreSrv Configuration

### Directory Structure

```
/opt/Orion-Sentinel-CoreSrv/          # Repository root
├── env/
│   ├── .env.core                     # Core services configuration
│   ├── .env.monitoring               # Monitoring stack configuration
│   └── .env.cloud                    # Cloud services configuration
├── config/
│   └── traefik/
│       └── dynamic/                  # Traefik dynamic configuration
├── stacks/                           # Docker Compose stacks
└── orionctl.sh                       # Control script

/srv/orion-sentinel-core/             # Data root
├── config/                           # Configuration files
├── monitoring/                       # Monitoring data
│   ├── prometheus/                   # Prometheus data
│   ├── loki/                         # Loki data
│   └── grafana/                      # Grafana data
├── cloud/                            # Cloud service data
└── backups/                          # Backup storage
```

### .env.core Configuration

Located at: `/opt/Orion-Sentinel-CoreSrv/env/.env.core`

**Required Settings:**

```bash
# Domain Configuration
DOMAIN=local
# If using real domain:
# DOMAIN=yourdomain.com

# Authelia Secrets (MUST be set)
AUTHELIA_JWT_SECRET=<generate-with-openssl-rand-base64-64>
AUTHELIA_SESSION_SECRET=<generate-with-openssl-rand-base64-64>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<generate-with-openssl-rand-base64-64>

# Traefik Configuration
TRAEFIK_DASHBOARD_ENABLED=true
TRAEFIK_LOG_LEVEL=INFO

# Network Settings
DOCKER_NETWORK=orion-core
```

**Generate secrets:**
```bash
openssl rand -base64 64
```

### .env.monitoring Configuration

Located at: `/opt/Orion-Sentinel-CoreSrv/env/.env.monitoring`

**Required Settings:**

```bash
# Data Paths
MONITORING_ROOT=/srv/orion-sentinel-core/monitoring

# Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<your-secure-password>
GRAFANA_PORT=3000

# Prometheus Configuration
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION_TIME=90d

# Loki Configuration
LOKI_PORT=3100
LOKI_RETENTION_PERIOD=720h  # 30 days

# Alert Manager (if configured)
ALERTMANAGER_ENABLED=false
```

### Traefik Dynamic Configuration

Create files in `/opt/Orion-Sentinel-CoreSrv/config/traefik/dynamic/` to expose Pi services.

**Example: DNS Pi Admin (dns-pi.yml)**
```yaml
http:
  routers:
    dns-admin:
      rule: "Host(`dns.local`)"
      service: dns-admin
      entryPoints:
        - websecure
      middlewares:
        - authelia
      tls:
        certResolver: letsencrypt  # or use internal CA

  services:
    dns-admin:
      loadBalancer:
        servers:
          - url: "http://192.168.1.100"
```

**Example: NetSec Service (netsec-pi.yml)**
```yaml
http:
  routers:
    netsec-ui:
      rule: "Host(`security.local`)"
      service: netsec-ui
      entryPoints:
        - websecure
      middlewares:
        - authelia

  services:
    netsec-ui:
      loadBalancer:
        servers:
          - url: "http://192.168.1.101:8080"  # Adjust port as needed
```

---

## Pi #1 (DNS) Configuration

### Repository Location

Default: `/opt/rpi-ha-dns-stack`

### .env Configuration

Located at: `/opt/rpi-ha-dns-stack/.env`

**Key Settings:**

```bash
# Network Configuration
PI_IP=192.168.1.100                   # This Pi's IP address
PI_INTERFACE=eth0                      # Network interface

# High Availability (if using multiple DNS Pis)
KEEPALIVED_ENABLED=true                # Set to true for HA
KEEPALIVED_VIRTUAL_IP=192.168.1.50    # VIP for HA
KEEPALIVED_STATE=MASTER                # MASTER or BACKUP
KEEPALIVED_PRIORITY=100                # Higher = primary (100 for master, 90 for backup)
KEEPALIVED_ROUTER_ID=51                # Unique ID for VRRP

# Pi-hole Configuration
PIHOLE_PASSWORD=<admin-password>       # Web interface password
PIHOLE_DNS1=1.1.1.1                   # Upstream DNS 1
PIHOLE_DNS2=1.0.0.1                   # Upstream DNS 2

# Unbound Configuration
UNBOUND_ENABLED=true                   # Enable recursive DNS with Unbound

# Timezone
TZ=America/New_York
```

### Promtail Configuration

Automatically created at: `/etc/promtail/promtail-config.yml`

**Configuration (auto-generated by bootstrap script):**

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://CORESRV_IP:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: pi-dns
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - docker: {}
```

**Key Points:**
- `url`: Points to CoreSrv Loki (`http://CORESRV_IP:3100/loki/api/v1/push`)
- `host`: Label is `pi-dns` for filtering in Grafana
- Scrapes Docker container logs from `/var/lib/docker/containers/`

---

## Pi #2 (NetSec) Configuration

### Repository Location

Default: `/opt/Orion-sentinel-netsec-ai`

### .env Configuration

Located at: `/opt/Orion-sentinel-netsec-ai/.env`

**SPoG Mode Settings (set by bootstrap script):**

```bash
# Loki Configuration (points to CoreSrv)
LOKI_URL=http://192.168.1.10:3100

# Disable local observability (use CoreSrv instead)
LOCAL_OBSERVABILITY=false
```

**Additional Settings (depends on NetSec repository):**

```bash
# Network Interface for Monitoring
NSM_INTERFACE=eth0

# Suricata Configuration
SURICATA_ENABLED=true

# AI Detection
AI_ENABLED=true
AI_MODEL=default

# Timezone
TZ=America/New_York
```

### Promtail Configuration

If Promtail is part of the NetSec repository, it should be configured via `LOKI_URL` in `.env`.

If manually deployed (similar to DNS Pi), configuration would be:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://CORESRV_IP:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: pi-netsec
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - docker: {}
```

---

## Promtail Configuration

### General Promtail Setup

Promtail agents run on both Pis to forward logs to CoreSrv Loki.

**Deployment Method:**
- Docker container: `grafana/promtail:2.9.3`
- Config file: `/etc/promtail/promtail-config.yml`
- Container name: `promtail`

**Container Configuration:**
```bash
docker run -d \
    --name promtail \
    --restart unless-stopped \
    -v /etc/promtail/promtail-config.yml:/etc/promtail/config.yml:ro \
    -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    grafana/promtail:2.9.3 \
    -config.file=/etc/promtail/config.yml
```

### Configuration Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `server.http_listen_port` | Promtail HTTP port | `9080` |
| `clients[].url` | Loki push endpoint | `http://192.168.1.10:3100/loki/api/v1/push` |
| `labels.host` | Host identifier for logs | `pi-dns` or `pi-netsec` |
| `labels.job` | Job name | `docker` |
| `__path__` | Log file path pattern | `/var/lib/docker/containers/*/*-json.log` |

### Querying Logs in Grafana

**Filter by host:**
```
{host="pi-dns"}
{host="pi-netsec"}
```

**Filter by job and host:**
```
{job="docker", host="pi-dns"}
```

**Filter by container name:**
```
{host="pi-dns", container_name="pihole"}
```

**Search for specific text:**
```
{host="pi-netsec"} |= "error"
{host="pi-dns"} |= "blocked"
```

---

## Environment Variables

### Bootstrap Script Variables

These can be set before running bootstrap scripts to override defaults.

#### bootstrap-coresrv.sh

| Variable | Default | Description |
|----------|---------|-------------|
| `CORESRV_REPO_URL` | `https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv.git` | CoreSrv repository URL |
| `CORESRV_REPO_BRANCH` | `main` | CoreSrv repository branch |
| `CORESRV_REPO_DIR` | `/opt/Orion-Sentinel-CoreSrv` | Installation directory |
| `CORESRV_DATA_ROOT` | `/srv/orion-sentinel-core` | Data storage root |

#### bootstrap-pi1-dns.sh

| Variable | Default | Description |
|----------|---------|-------------|
| `PI_DNS_HOST` | (none) | Pi DNS hostname or IP (empty = local) |
| `CORESRV_IP` | (none) | CoreSrv IP for log forwarding |
| `DNS_REPO_URL` | `https://github.com/yorgosroussakis/rpi-ha-dns-stack.git` | DNS repository URL |
| `DNS_REPO_BRANCH` | `main` | DNS repository branch |
| `DNS_REPO_DIR` | `/opt/rpi-ha-dns-stack` | Installation directory |
| `PROMTAIL_VERSION` | `2.9.3` | Promtail Docker image version |

#### bootstrap-pi2-netsec.sh

| Variable | Default | Description |
|----------|---------|-------------|
| `PI_NETSEC_HOST` | (none) | Pi NetSec hostname or IP (empty = local) |
| `CORESRV_IP` | (none) | CoreSrv IP for log forwarding |
| `NETSEC_REPO_URL` | `https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai.git` | NetSec repository URL |
| `NETSEC_REPO_BRANCH` | `main` | NetSec repository branch |
| `NETSEC_REPO_DIR` | `/opt/Orion-sentinel-netsec-ai` | Installation directory |

#### deploy-orion-sentinel.sh

All of the above variables can be set before running the orchestration script.

### Usage Examples

**Custom repository for testing:**
```bash
export DNS_REPO_URL="https://github.com/youruser/rpi-ha-dns-stack.git"
export DNS_REPO_BRANCH="develop"
./scripts/bootstrap-pi1-dns.sh
```

**Full deployment with custom settings:**
```bash
export CORESRV_IP="10.0.0.10"
export PI_DNS_HOST="10.0.0.100"
export PI_NETSEC_HOST="10.0.0.101"
./scripts/deploy-orion-sentinel.sh
```

---

## Configuration Best Practices

1. **Use Static IPs**: Set static IPs or DHCP reservations for all three nodes
2. **Strong Secrets**: Always generate strong random secrets for Authelia
3. **Backup Configuration**: Backup `.env` files and Traefik configs regularly
4. **Document Changes**: Keep notes of any custom configuration changes
5. **Test Before Production**: Test the full stack in a lab environment first
6. **Monitor Logs**: Regularly check Loki for errors and issues
7. **Update Regularly**: Keep Docker images and repositories up to date
8. **Secure Access**: Use Authelia or VPN for external access to services

---

## Troubleshooting Configuration Issues

### Promtail Not Forwarding Logs

**Check Promtail configuration:**
```bash
ssh pi@pi-dns-ip
sudo cat /etc/promtail/promtail-config.yml
```

**Verify Loki URL is correct:**
- Should be `http://CORESRV_IP:3100/loki/api/v1/push`
- Make sure CoreSrv IP is reachable from Pi

**Test connectivity:**
```bash
curl http://CORESRV_IP:3100/ready
```

### Services Not Starting on CoreSrv

**Check environment files:**
```bash
cat /opt/Orion-Sentinel-CoreSrv/env/.env.core
cat /opt/Orion-Sentinel-CoreSrv/env/.env.monitoring
```

**Verify all required secrets are set:**
- `AUTHELIA_JWT_SECRET`
- `AUTHELIA_SESSION_SECRET`
- `AUTHELIA_STORAGE_ENCRYPTION_KEY`

### DNS Not Working

**Check Pi-hole configuration:**
```bash
ssh pi@pi-dns-ip
cd /opt/rpi-ha-dns-stack
cat .env | grep -E "(PI_IP|PIHOLE_DNS|UNBOUND)"
```

**Verify containers are running:**
```bash
docker ps | grep -E "(pihole|unbound)"
```

---

## Additional Resources

- [Getting Started Guide](GETTING-STARTED-THREE-NODE.md)
- [Grafana Loki Documentation](https://grafana.com/docs/loki/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Authelia Documentation](https://www.authelia.com/)

For component-specific configuration, refer to their respective repositories:
- [Orion-Sentinel-CoreSrv](https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv)
- [rpi-ha-dns-stack](https://github.com/yorgosroussakis/rpi-ha-dns-stack)
- [Orion-sentinel-netsec-ai](https://github.com/yorgosroussakis/Orion-sentinel-netsec-ai)
