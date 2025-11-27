/**
 * Orion Sentinel Dashboard - Configuration
 * 
 * Edit the service URLs below to match your network setup.
 * The homepage will automatically use these URLs for service links.
 */

window.ORION_CONFIG = {
    // Core Services (CoreSrv)
    services: {
        grafana: {
            name: "Grafana",
            description: "Monitoring & Dashboards",
            url: "http://grafana.local",
            icon: "grafana",
            category: "core"
        },
        traefik: {
            name: "Traefik",
            description: "Reverse Proxy",
            url: "http://traefik.local",
            icon: "traefik",
            category: "core"
        },
        authelia: {
            name: "Authelia",
            description: "Authentication",
            url: "http://auth.local",
            icon: "authelia",
            category: "core"
        },
        
        // DNS & Privacy (Pi #1)
        pihole: {
            name: "Pi-hole",
            description: "Ad Blocking & DNS",
            url: "http://pi.hole/admin",
            icon: "pihole",
            category: "dns"
        },
        
        // Network Security (Pi #2)
        suricata: {
            name: "Suricata",
            description: "Intrusion Detection",
            url: "http://suricata.local",
            icon: "suricata",
            category: "security"
        },
        loki: {
            name: "Loki",
            description: "Log Aggregation",
            url: "http://loki.local:3100",
            icon: "loki",
            category: "security"
        },
        prometheus: {
            name: "Prometheus",
            description: "Metrics Collection",
            url: "http://prometheus.local:9090",
            icon: "prometheus",
            category: "security"
        }
    },
    
    // Category labels
    categories: {
        core: "Core Services",
        dns: "DNS & Privacy",
        security: "Network Security"
    },
    
    // Dashboard settings
    settings: {
        title: "Orion Sentinel",
        subtitle: "Home Network Security Suite",
        checkStatus: false,  // Set to true to enable status checks (requires CORS)
        statusInterval: 30000  // Status check interval in ms
    }
};
