# Getting Started with Orion Sentinel on Two Raspberry Pis

This guide will walk you through setting up a complete Orion Sentinel deployment on two Raspberry Pis, from initial hardware setup to a fully functional network security and privacy suite.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Hardware Setup](#hardware-setup)
3. [Initial Pi Configuration](#initial-pi-configuration)
4. [Installing Pi #1 (DNS & Privacy)](#installing-pi-1-dns--privacy)
5. [Installing Pi #2 (Security & Monitoring)](#installing-pi-2-security--monitoring)
6. [Network Configuration](#network-configuration)
7. [Verification and Testing](#verification-and-testing)
8. [Advanced Configuration](#advanced-configuration)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware Requirements

- **2× Raspberry Pi 4 or 5** (4GB RAM minimum, 8GB recommended)
- **2× MicroSD cards** (32GB minimum, Class 10 or better)
- **2× Power supplies** (official Raspberry Pi power supplies recommended)
- **Network switch** with port mirroring/SPAN capability (optional but recommended for Pi #2)
- **Ethernet cables**
- **Computer** for initial setup and SSH access

### Software Requirements

- **Raspberry Pi Imager** - [Download here](https://www.raspberrypi.com/software/)
- **SSH client** (built-in on Linux/macOS, use PuTTY on Windows)

### Knowledge Requirements

- Basic Linux command line familiarity
- Understanding of home networking concepts
- SSH access experience

## Hardware Setup

### Step 1: Prepare the SD Cards

1. **Download Raspberry Pi Imager** to your computer

2. **Flash Raspberry Pi OS to both SD cards:**
   - Insert first SD card
   - Open Raspberry Pi Imager
   - Choose OS: **Raspberry Pi OS (64-bit)** - preferably the Lite version for headless operation
   - Choose Storage: Your SD card
   - Click the **gear icon** for advanced options:
     - ✅ Enable SSH (use password authentication or set up SSH keys)
     - ✅ Set username and password (e.g., username: `pi`, password: `<your-password>`)
     - ✅ Configure WiFi (if using WiFi instead of Ethernet)
     - ✅ Set locale settings (timezone, keyboard layout)
   - Click **Write** and wait for completion
   - Repeat for the second SD card

3. **Label your SD cards** physically (e.g., "Pi1-DNS" and "Pi2-NSM") to avoid confusion

### Step 2: Physical Setup

1. **Pi #1 (DNS):**
   - Insert the first SD card
   - Connect to your network via Ethernet (recommended) or WiFi
   - Connect power supply
   - Note the IP address (check your router's DHCP table or use `nmap`)

2. **Pi #2 (NSM):**
   - Insert the second SD card
   - Connect to your network via Ethernet
   - If you have a managed switch with port mirroring, connect Pi #2 to the mirror destination port
   - Connect power supply
   - Note the IP address

### Step 3: Verify Network Access

Test SSH access to both Pis:

```bash
# Test Pi #1
ssh pi@<pi1-ip-address>

# Test Pi #2
ssh pi@<pi2-ip-address>
```

If successful, you should see a login prompt. If not, check:
- Network connectivity
- SSH is enabled
- Correct IP address
- Firewall settings

## Initial Pi Configuration

Perform these steps on **both Raspberry Pis** before running the installer scripts.

### Step 1: Update the System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

This may take several minutes.

### Step 2: Set Static IP (Recommended)

For stability, set static IP addresses for both Pis.

**Option A: Via your router's DHCP settings (recommended)**
- Configure DHCP reservations for both Pis' MAC addresses
- This ensures they always get the same IP

**Option B: Via the Pi's network configuration**

Edit `/etc/dhcpcd.conf`:

```bash
sudo nano /etc/dhcpcd.conf
```

Add at the end (adjust values for your network):

```bash
interface eth0
static ip_address=192.168.1.100/24  # For Pi #1, use .101 for Pi #2
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

Save and reboot:

```bash
sudo reboot
```

### Step 3: Set Hostnames (Optional but Recommended)

**On Pi #1:**
```bash
sudo hostnamectl set-hostname orion-dns
```

**On Pi #2:**
```bash
sudo hostnamectl set-hostname orion-nsm
```

Reboot to apply:
```bash
sudo reboot
```

## Installing Pi #1 (DNS & Privacy)

SSH into Pi #1:

```bash
ssh pi@<pi1-ip-address>
```

### Step 1: Clone the Installer Repository

```bash
git clone https://github.com/yorgosroussakis/orion-sentinel-installer.git
cd orion-sentinel-installer
```

### Step 2: Run the Bootstrap Script

```bash
./scripts/bootstrap-pi1-dns.sh
```

The script will:
1. Install Docker and Docker Compose (if not already installed)
2. Clone the `orion-sentinel-dns-ha` repository to `~/orion/orion-sentinel-dns-ha`
3. Run the DNS installation script
4. Set up Pi-hole and related services

**Note:** The first run will take 10-20 minutes as it downloads and installs Docker and pulls container images.

### Step 3: Note the Output

At the end of the installation, you'll see important information:

- **Pi-hole Admin URL:** `http://<pi1-ip>/admin`
- **Admin Password:** Check the `.env` file or installation output
- **DNS Server IP:** Your Pi #1's IP address

Save this information for later use.

### Step 4: Access Pi-hole

Open a web browser and navigate to:

```
http://<pi1-ip>/admin
```

Log in with the admin password shown during installation.

## Installing Pi #2 (Security & Monitoring)

SSH into Pi #2:

```bash
ssh pi@<pi2-ip-address>
```

### Step 1: Clone the Installer Repository

```bash
git clone https://github.com/yorgosroussakis/orion-sentinel-installer.git
cd orion-sentinel-installer
```

### Step 2: Run the Bootstrap Script

```bash
./scripts/bootstrap-pi2-nsm.sh
```

The script will:
1. Install Docker and Docker Compose (if not already installed)
2. Clone the `orion-sentinel-nsm-ai` repository to `~/orion/orion-sentinel-nsm-ai`
3. Run the NSM installation script
4. Set up Suricata, Grafana, and related services

**Note:** This will also take 10-20 minutes on the first run.

### Step 3: Note the Output

At the end of the installation, you'll see:

- **Grafana URL:** `http://<pi2-ip>:3000`
- **Default Grafana credentials:** admin/admin (you'll be prompted to change on first login)
- **NSM Wizard URL:** `http://<pi2-ip>:8081` (if available)

### Step 4: Access Grafana

Open a web browser and navigate to:

```
http://<pi2-ip>:3000
```

Log in with `admin/admin` and set a new password when prompted.

## Network Configuration

### Configure Router DNS

To enable network-wide ad blocking and privacy protection:

1. **Access your router's admin interface** (usually `http://192.168.1.1` or similar)

2. **Navigate to DHCP/DNS settings**

3. **Set Primary DNS Server** to Pi #1's IP address (e.g., `192.168.1.100`)

4. **Set Secondary DNS Server** (optional):
   - If you have HA setup: your secondary Pi-hole IP
   - Otherwise: a public DNS like `1.1.1.1` or `8.8.8.8` for fallback

5. **Save and reboot your router**

6. **Renew DHCP leases** on your devices or wait for automatic renewal

### Configure Port Mirroring (Optional but Recommended)

For Pi #2 to monitor network traffic effectively:

1. **Access your managed switch's configuration**

2. **Create a port mirror/SPAN session:**
   - **Source:** The port(s) you want to monitor (e.g., router uplink port)
   - **Destination:** The port where Pi #2 is connected

3. **Save the configuration**

**Note:** This step requires a managed switch with port mirroring capability. Without this, the NSM functionality will be limited.

## Verification and Testing

### Test DNS Filtering (Pi #1)

1. **Verify DNS is working:**

   ```bash
   nslookup google.com <pi1-ip>
   ```

   You should get a valid response.

2. **Test ad blocking:**

   Visit a website known for ads. Ads should be blocked if DNS is configured correctly on your device.

3. **Check Pi-hole stats:**

   Go to `http://<pi1-ip>/admin` and verify you see queries being logged.

### Test Network Monitoring (Pi #2)

1. **Check running services:**

   ```bash
   ssh pi@<pi2-ip>
   cd ~/orion/orion-sentinel-nsm-ai
   docker compose ps
   ```

   All services should be in "Up" state.

2. **Access Grafana dashboards:**

   Navigate to `http://<pi2-ip>:3000` and explore the pre-configured dashboards.

3. **Verify network monitoring:**

   If port mirroring is configured, you should see network traffic in the dashboards.

## Advanced Configuration

### High Availability DNS Setup

To set up DNS high availability with two Pi-hole instances:

1. **Prepare a second Pi** with the DNS bootstrap script

2. **Edit configuration on both Pis:**

   ```bash
   cd ~/orion/orion-sentinel-dns-ha
   nano .env
   ```

3. **Configure Keepalived settings:**
   - Set `KEEPALIVED_VIRTUAL_IP` to a free IP on your network
   - Configure `KEEPALIVED_PRIORITY` (higher on primary, lower on secondary)
   - Set `KEEPALIVED_STATE` (MASTER on primary, BACKUP on secondary)

4. **Restart services:**

   ```bash
   docker compose down
   docker compose up -d
   ```

5. **Update router DNS to use the Virtual IP**

See the [DNS HA documentation](https://github.com/yorgosroussakis/orion-sentinel-dns-ha) for detailed instructions.

### Customize NSM Monitoring

To change monitored network interfaces or add custom detection rules:

1. **Edit NSM configuration:**

   ```bash
   cd ~/orion/orion-sentinel-nsm-ai
   nano .env
   ```

2. **Set the monitoring interface:**

   ```
   NSM_INTERFACE=eth0  # or your mirror port interface
   ```

3. **Restart services:**

   ```bash
   docker compose down
   docker compose up -d
   ```

See the [NSM AI documentation](https://github.com/yorgosroussakis/orion-sentinel-nsm-ai) for advanced configuration.

## Troubleshooting

### Docker Permission Issues

**Problem:** `permission denied while trying to connect to the Docker daemon`

**Solution:**
```bash
# Log out and log back in, or run:
newgrp docker
```

### Pi-hole Not Blocking Ads

**Problem:** Ads still appear on websites

**Solutions:**
1. Verify your device is using Pi #1 as DNS server: `nslookup google.com`
2. Clear browser cache and cookies
3. Some ads may require additional blocklists
4. Check Pi-hole query log for blocked domains

### No Network Traffic Visible in Grafana

**Problem:** NSM dashboards show no traffic

**Solutions:**
1. Verify port mirroring is configured correctly on your switch
2. Check the NSM interface setting in `.env`
3. Verify Suricata is running: `docker compose ps`
4. Check Suricata logs: `docker compose logs suricata`

### Services Won't Start

**Problem:** Docker containers fail to start

**Solutions:**
1. Check logs: `docker compose logs`
2. Verify sufficient disk space: `df -h`
3. Ensure no port conflicts: `sudo netstat -tulpn`
4. Try rebuilding: `docker compose down && docker compose up -d --force-recreate`

### Can't SSH to Raspberry Pi

**Problem:** Connection refused or timeout

**Solutions:**
1. Verify Pi is powered on and connected to network
2. Check IP address hasn't changed
3. Verify SSH is enabled during Pi setup
4. Check firewall rules on your network

### Installation Script Fails

**Problem:** Bootstrap script exits with error

**Solutions:**
1. Check internet connectivity on the Pi
2. Verify sufficient disk space
3. Review error messages in the script output
4. Try running the script again (it's designed to be idempotent)
5. Check the respective component repository for specific issues

## Next Steps

After successful installation:

1. **Explore Pi-hole features:**
   - Add custom blocklists
   - Whitelist/blacklist specific domains
   - Set up local DNS records

2. **Customize Grafana dashboards:**
   - Create custom queries
   - Set up alerts
   - Add new visualizations

3. **Review security alerts:**
   - Monitor Suricata alerts
   - Investigate suspicious activity
   - Fine-tune detection rules

4. **Regular maintenance:**
   - Update Docker images periodically
   - Review and update blocklists
   - Check disk usage and logs

## Additional Resources

- **Main Repository:** [orion-sentinel-installer](https://github.com/yorgosroussakis/orion-sentinel-installer)
- **DNS Component:** [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/orion-sentinel-dns-ha)
- **NSM Component:** [orion-sentinel-nsm-ai](https://github.com/yorgosroussakis/orion-sentinel-nsm-ai)
- **Pi-hole Documentation:** [https://docs.pi-hole.net/](https://docs.pi-hole.net/)
- **Suricata Documentation:** [https://suricata.io/](https://suricata.io/)
- **Grafana Documentation:** [https://grafana.com/docs/](https://grafana.com/docs/)

## Getting Help

If you encounter issues:

1. Check this troubleshooting guide
2. Review the component-specific documentation
3. Search existing GitHub issues
4. Open a new issue with:
   - Your Pi model and OS version
   - Detailed error messages
   - Steps to reproduce the problem
   - Relevant log output

Happy monitoring! 🛡️🔒
