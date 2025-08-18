(function() {
  // Default environment variables
  const defaults = {
    NEXT_PUBLIC_COUCHDB_URL: 'http://localhost:5984',
    NEXT_PUBLIC_COUCHDB_USERNAME: 'admin', 
    NEXT_PUBLIC_COUCHDB_PASSWORD: 'admin',
    NODE_ENV: 'production'
  };

  // Initialize window.ENV
  window.ENV = window.ENV || {};

  // Apply defaults first
  Object.assign(window.ENV, defaults);

  // Override with meta tags if present
  document.querySelectorAll('meta[name^="env:"]').forEach(meta => {
    const key = meta.getAttribute('name').replace('env:', '');
    const value = meta.getAttribute('content');
    if (key && value) {
      window.ENV[key] = value;
    }
  });

  // Development overrides from localStorage
  if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    try {
      const overrides = localStorage.getItem('pos_env_overrides');
      if (overrides) {
        Object.assign(window.ENV, JSON.parse(overrides));
      }
    } catch (e) {
      // Ignore errors
    }
  }

  console.log('Environment initialized:', {
    ...window.ENV,
    NEXT_PUBLIC_COUCHDB_PASSWORD: '***'
  });
})();