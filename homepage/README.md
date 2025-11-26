# Orion Sentinel Homepage

A modern, customizable dashboard for accessing all your homelab services from a central location.

## Features

- 🎨 Clean, modern dark theme (with light mode support)
- 📱 Fully responsive design
- ⚡ Fast, lightweight (static HTML/CSS/JS)
- 🔧 Easy to configure via JSON
- 🐳 Docker-ready with nginx

## Quick Start

### Option 1: Docker Compose (Recommended)

```bash
cd homepage
docker compose up -d
```

Access the homepage at `http://localhost` (or your configured port).

### Option 2: Standalone (No Docker)

Simply serve the `html/` directory with any web server:

```bash
# Python
cd html && python3 -m http.server 8080

# Node.js (http-server)
npx http-server html -p 8080

# nginx/apache
# Copy html/ contents to your web root
```

## Configuration

### Customizing Services

Edit `html/services.json` to add, remove, or modify the services displayed:

```json
{
    "core": [
        {
            "name": "Grafana",
            "description": "Visualization & Dashboards",
            "url": "http://192.168.1.50:3000",
            "icon": "chart",
            "color": "#f46800"
        }
    ],
    "monitoring": [...],
    "network": [...],
    "additional": [...]
}
```

### Service Categories

| Category | Purpose |
|----------|---------|
| `core` | Core infrastructure services (Grafana, Traefik, Authelia) |
| `monitoring` | Monitoring and observability tools (Prometheus, Loki) |
| `network` | Network services (Pi-hole, Suricata) |
| `additional` | Any other services you want to add |

### Available Icons

| Icon | Description |
|------|-------------|
| `chart` | Dashboard/visualization services |
| `network` | Network/proxy services |
| `shield` | Security/authentication services |
| `metrics` | Metrics/monitoring services |
| `logs` | Logging services |
| `dns` | DNS services |
| `security` | IDS/security services |
| `server` | Server management |
| `cloud` | Cloud storage |
| `database` | Database services |
| `home` | Home automation |
| `media` | Media servers |
| `download` | Download managers |
| `settings` | Configuration/settings |
| `link` | Generic link (default) |

### Environment Variables

Set these in a `.env` file or pass them to docker compose:

| Variable | Default | Description |
|----------|---------|-------------|
| `HOMEPAGE_PORT` | `80` | Port to expose the homepage |
| `HOMEPAGE_DOMAIN` | `home.local` | Domain for Traefik routing |
| `ORION_NETWORK` | `orion-network` | Docker network name |

## Integration with CoreSrv

To deploy the homepage as part of your CoreSrv setup:

1. **Copy the homepage directory to CoreSrv:**
   ```bash
   scp -r homepage/ user@coresrv:/opt/Orion-Sentinel-CoreSrv/
   ```

2. **Configure services.json with your actual IPs:**
   ```bash
   ssh user@coresrv
   cd /opt/Orion-Sentinel-CoreSrv/homepage
   nano html/services.json
   ```

3. **Start the homepage:**
   ```bash
   docker compose up -d
   ```

4. **Add DNS entry for easy access:**
   - In Pi-hole: Add `home.local` → `<coresrv-ip>`
   - Or in `/etc/hosts`: `192.168.1.50  home.local`

## Theming

The homepage uses CSS custom properties for easy theming. Edit `html/styles.css` to customize:

```css
:root {
    --bg-primary: #0f1419;      /* Main background */
    --bg-card: #232f3e;         /* Card background */
    --text-primary: #e5e7eb;    /* Main text color */
    --accent-primary: #4fd1c5;  /* Accent color */
    /* ... more variables */
}
```

The homepage automatically respects the user's system color scheme preference (dark/light mode).

## Screenshots

The homepage provides a clean, organized view of all your services:

- **Core Services**: Central infrastructure like Grafana and Traefik
- **Monitoring**: Prometheus, Loki, and other observability tools
- **Network**: Pi-hole, Suricata, and network management
- **Additional**: Any other services in your homelab stack

## Troubleshooting

### Services not loading

1. Check that `services.json` is valid JSON:
   ```bash
   cat html/services.json | jq .
   ```

2. Check browser console for JavaScript errors

3. Ensure the file is being served with correct MIME type

### Container won't start

1. Check if port 80 is already in use:
   ```bash
   sudo lsof -i :80
   ```

2. Use a different port:
   ```bash
   HOMEPAGE_PORT=8888 docker compose up -d
   ```

### Traefik integration not working

1. Ensure the `orion-network` exists:
   ```bash
   docker network create orion-network
   ```

2. Check Traefik labels are correct in `docker-compose.yml`

## License

MIT License - see the main repository LICENSE file.
