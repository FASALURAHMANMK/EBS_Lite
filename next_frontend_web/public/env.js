(function() {
  // Initialize window.ENV
  window.ENV = window.ENV || {};

  // Override with meta tags if present
  document.querySelectorAll('meta[name^="env:"]').forEach(meta => {
    const key = meta.getAttribute('name').replace('env:', '');
    const value = meta.getAttribute('content');
    if (key && value) {
      window.ENV[key] = value;
    }
  });

  const isDev =
    window.location.hostname === 'localhost' ||
    window.location.hostname === '127.0.0.1';

  // Development overrides from localStorage
  if (isDev) {
    try {
      const overrides = localStorage.getItem('pos_env_overrides');
      if (overrides) {
        Object.assign(window.ENV, JSON.parse(overrides));
      }
    } catch (e) {
      // Ignore errors
    }
  }

  if (isDev) {
    console.log('Environment initialized:', window.ENV);
  }
})();
