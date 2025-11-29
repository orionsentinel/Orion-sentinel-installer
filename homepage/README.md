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

Access at: `http://localhost:8080`

### Static Files (No Docker)

Simply serve the files with any web server:

```bash
# Using Python
python3 -m http.server 8080

# Using Node.js
npx serve .
```

## Configuration

Edit `assets/config.js` to customize service URLs for your network:

```javascript
window.ORION_CONFIG = {
    services: {
        grafana: {
            name: "Grafana",
            description: "Monitoring & Dashboards",
            url: "http://192.168.1.50:3000",  // Your Grafana URL
            icon: "grafana",
            category: "core"
        },
        // ... more services
    }
};
```

### Service URL Examples

| Service | Default URL | Example Custom URL |
|---------|-------------|-------------------|
| Grafana | `http://grafana.local` | `http://192.168.1.50:3000` |
| Pi-hole | `http://pi.hole/admin` | `http://192.168.1.10/admin` |
| Traefik | `http://traefik.local` | `http://192.168.1.50:8080` |
| Authelia | `http://auth.local` | `http://192.168.1.50:9091` |

## Integration with CoreSrv

The homepage can be deployed alongside your CoreSrv stack. To integrate with Traefik:

1. Add the Traefik labels in `docker-compose.yml`
2. Configure your DNS or `/etc/hosts` to point `home.local` to CoreSrv
3. Access via `http://home.local`

## Adding Custom Services

1. Edit `assets/config.js` to add your service:

```javascript
myservice: {
    name: "My Service",
    description: "Custom service description",
    url: "http://myservice.local:8000",
    icon: "default",
    category: "custom"
}
```

2. Add the HTML in `index.html`:

```html
<a href="http://myservice.local:8000" class="service-card" data-service="myservice">
    <div class="service-icon default">
        <!-- SVG icon here -->
    </div>
    <div class="service-info">
        <h3>My Service</h3>
        <p>Custom service description</p>
    </div>
    <span class="service-arrow">→</span>
</a>
```

3. Add icon styling in `assets/style.css`:

```css
.service-icon.default {
    background: rgba(100, 100, 100, 0.15);
    color: #888;
}
```

## File Structure

```
homepage/
├── index.html          # Main dashboard page
├── docker-compose.yml  # Docker deployment
├── README.md           # This file
├── assets/
│   ├── style.css       # Dashboard styling
│   ├── config.js       # Service configuration
│   ├── app.js          # Dashboard logic
│   └── favicon.svg     # Browser icon
└── config/
    └── nginx.conf      # Nginx configuration
```

## Customization

### Colors

Edit the CSS variables in `assets/style.css`:

```css
:root {
    --bg-primary: #0f172a;      /* Main background */
    --accent-primary: #3b82f6;  /* Primary accent color */
    /* ... more variables */
}
```

### Service Icons

Each service has a unique color defined in the CSS:

```css
--color-grafana: #f46800;
--color-pihole: #96060c;
/* ... */
```

## License

MIT License - Part of the Orion Sentinel project.
