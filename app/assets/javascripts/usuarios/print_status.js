App.onMount('#edit-usuario #impresion', function() {
  var indicator = document.getElementById('qz-status-indicator');
  var statusText = document.getElementById('qz-status-text');
  var btn = document.getElementById('qz-test-connection');

  if (!indicator || !statusText) return;

  function setStatus(color, text) {
    indicator.style.background = color;
    statusText.textContent = text;
  }

  function checkConnection() {
    setStatus('#ffc107', 'Verificando...');

    var servicio = $('body').data('servicio-impresion');

    if (servicio === 'qztray') {
      if (typeof qz === 'undefined') {
        setStatus('#dc3545', 'QZ Tray SDK no cargado');
        return;
      }
      qz.websocket.connect({retries: 1, delay: 0.5})
        .then(function() { return qz.printers.getDefault(); })
        .then(function(printer) {
          setStatus('#28a745', 'Conectado — Impresora: ' + printer);
          qz.websocket.disconnect();
        })
        .catch(function(err) {
          setStatus('#dc3545', 'Sin conexión — ¿Está abierto QZ Tray? (' + (err.message || err) + ')');
        });
    } else {
      var ws;
      try {
        ws = new WebSocket('wss://127.0.0.1:12212/printer?access_token=VitoWHB');
      } catch(e) {
        setStatus('#dc3545', 'Sin conexión — ¿Está abierto WHB?');
        return;
      }
      ws.onopen = function() {
        setStatus('#28a745', 'Conectado a WHB');
        ws.close();
      };
      ws.onerror = function() {
        setStatus('#dc3545', 'Sin conexión — ¿Está abierto WHB?');
      };
      ws.onclose = function() {};
    }
  }

  if (btn) {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      checkConnection();
    });
  }

  checkConnection();
});
