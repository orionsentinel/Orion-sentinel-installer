/**
 * Orion Sentinel Dashboard - Application Logic
 * Lightweight JavaScript for dynamic URL configuration
 */

(function() {
    'use strict';

    // Wait for DOM and config to load
    document.addEventListener('DOMContentLoaded', function() {
        if (window.ORION_CONFIG) {
            initializeDashboard();
        }
    });

    function initializeDashboard() {
        const config = window.ORION_CONFIG;
        
        // Update service links from config
        updateServiceLinks(config.services);
        
        // Update page title if configured
        if (config.settings && config.settings.title) {
            document.title = config.settings.title + ' - Dashboard';
        }
    }

    function updateServiceLinks(services) {
        // Find all service cards and update their hrefs
        const serviceCards = document.querySelectorAll('.service-card[data-service]');
        
        serviceCards.forEach(function(card) {
            const serviceId = card.getAttribute('data-service');
            const service = services[serviceId];
            
            if (service && service.url) {
                card.href = service.url;
                
                // Update name and description if present
                const nameEl = card.querySelector('.service-info h3');
                const descEl = card.querySelector('.service-info p');
                
                if (nameEl && service.name) {
                    nameEl.textContent = service.name;
                }
                if (descEl && service.description) {
                    descEl.textContent = service.description;
                }
            }
        });
    }

    // Optional: Status checking (disabled by default due to CORS)
    function checkServiceStatus(url, callback) {
        if (!window.ORION_CONFIG.settings.checkStatus) {
            return;
        }

        const controller = new AbortController();
        const timeoutId = setTimeout(function() {
            controller.abort();
        }, 5000);

        fetch(url, { 
            method: 'HEAD', 
            mode: 'no-cors',
            signal: controller.signal 
        })
        .then(function() {
            clearTimeout(timeoutId);
            callback('online');
        })
        .catch(function() {
            clearTimeout(timeoutId);
            callback('unknown');
        });
    }

})();
