(function () {
  var hostname = location.hostname;
  var isLocalhost =
    hostname === 'localhost' ||
    hostname === '127.0.0.1' ||
    hostname === '' ||
    hostname.startsWith('192.168.') ||
    hostname.startsWith('10.');

  window.SERVIO_CONFIG = {
    API_BASE: isLocalhost
      ? 'http://127.0.0.1:5000/api/v1'
      : 'https://servio-backend.onrender.com/api/v1',
  };
})();
