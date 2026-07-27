// Dual Print Service: WHB WebSocket daemon + QZ Tray
// User selects which one to use via their profile (servicio_de_impresion)
(function() {
  // ==================== WHB WebSocket Printer ====================
  var WebSocketPrinter = function(opts) {
    var defaults = {
      url: "wss://127.0.0.1:12212/printer?access_token=VitoWHB",
      onConnect: function() {},
      onDisconnect: function() {},
      onMessage: function() {},
      attempsBeforeGivingUp: 5
    };

    this.opts = $.extend(defaults, opts);
    this.submitPromises = {};

    if (sessionStorage['printService.attempsRemaining'] == null) {
      sessionStorage['printService.attempsRemaining'] = this.opts.attempsBeforeGivingUp;
    }
  };

  WebSocketPrinter.INITIALIZED = -1;

  WebSocketPrinter.prototype.connect = function() {
    var self = this;

    if (sessionStorage['printService.attempsRemaining'] <= 0) {
      return Promise.reject();
    }

    if (this.isInitialized() || this.isDisconnected()) {
      sessionStorage['printService.attempsRemaining']--;

      this.connectPromise = new Promise(function(resolve, reject) {
        self.websocket = new WebSocket(self.opts.url);

        self.websocket.onopen = function() {
          sessionStorage['printService.attempsRemaining'] = self.opts.attempsBeforeGivingUp;
          resolve();
          self.opts.onConnect();
        };

        self.websocket.onclose = function(event) {
          reject();
          self.opts.onDisconnect();
          for (var key in self.submitPromises) {
            if (self.submitPromises.hasOwnProperty(key)) {
              self.submitPromises[key].resolve();
            }
          }
          self.submitPromises = {};
        };

        self.websocket.onmessage = function(event) {
          var message = JSON.parse(event.data);
          if (message.status === 0) {
            self.submitPromises[message.id].resolve(message);
          } else {
            self.submitPromises[message.id].reject(message);
          }
          delete self.submitPromises[message.id];
          self.opts.onMessage(message);
        };
      });
    }

    return this.connectPromise;
  };

  WebSocketPrinter.prototype.disconnect = function() {
    this.websocket.close();
  };

  WebSocketPrinter.prototype.status = function() {
    return this.websocket ? this.websocket.readyState : WebSocketPrinter.INITIALIZED;
  };

  WebSocketPrinter.prototype.isInitialized = function() {
    return this.status() === WebSocketPrinter.INITIALIZED;
  };

  WebSocketPrinter.prototype.isConnected = function() {
    return this.status() === WebSocket.OPEN;
  };

  WebSocketPrinter.prototype.isConnecting = function() {
    return this.status() === WebSocket.CONNECTING;
  };

  WebSocketPrinter.prototype.isDisconnected = function() {
    return this.status() === WebSocket.CLOSED;
  };

  WebSocketPrinter.prototype.submit = function(data) {
    var self = this;
    if (data.id == null) {
      data.id = Math.random();
    }
    return new Promise(function(resolve, reject) {
      self.submitPromises[data.id] = {resolve: resolve, reject: reject};
      if (self.isConnected()) {
        self.websocket.send(JSON.stringify(data));
      } else {
        throw Error('WebSocket not connected');
      }
    });
  };

  // ==================== QZ Tray Print Service ====================
  if (typeof qz !== 'undefined') {
    qz.security.setCertificatePromise(function(resolve, reject) {
      $.ajax({url: '/qz_certificate', cache: false, dataType: 'text'})
        .then(resolve, reject);
    });

    qz.security.setSignatureAlgorithm("SHA512"); // Required since QZ Tray 2.1

    qz.security.setSignaturePromise(function(toSign) {
      return function(resolve, reject) {
        var tk = $('meta[name="csrf-token"]').attr('content');
        $.ajax({url: '/qz_sign', type: 'POST', data: {request: toSign, authenticity_token: tk}, dataType: 'text'})
          .then(resolve, reject);
      };
    });
  }

  var QZPrintService = function() {
    this._defaultPrinter = null;
  };

  QZPrintService.prototype.connect = function() {
    if (typeof qz === 'undefined') { return Promise.reject(new Error('QZ Tray SDK not loaded')); }
    if (qz.websocket.isActive()) { return Promise.resolve(); }

    var self = this;
    return qz.websocket.connect({retries: 3, delay: 1}).then(function() {
      return qz.printers.getDefault();
    }).then(function(printer) {
      self._defaultPrinter = printer;
    });
  };

  QZPrintService.prototype.disconnect = function() {
    if (typeof qz !== 'undefined' && qz.websocket.isActive()) {
      return qz.websocket.disconnect();
    }
    return Promise.resolve();
  };

  QZPrintService.prototype.isConnected = function() {
    return typeof qz !== 'undefined' && qz.websocket.isActive();
  };

  QZPrintService.prototype.submit = function(data) {
    if (!this._defaultPrinter) { return Promise.reject(new Error('No default printer')); }

    var config = qz.configs.create(this._defaultPrinter, {margins: 0, scaleContent: true});
    var printData = [{
      type: 'pixel',
      format: 'pdf',
      flavor: 'base64',
      data: data.file_content
    }];

    return qz.print(config, printData);
  };

  // ==================== Service Selection ====================
  // Reads the user's preference from a data attribute on <body>
  // Default: WHB (for backward compatibility)
  function createPrintService() {
    var body = document.querySelector('body');
    var servicio = body ? body.getAttribute('data-servicio-impresion') : null;

    if (servicio === 'qztray') {
      return new QZPrintService();
    }
    return new WebSocketPrinter();
  }

  window.printService = createPrintService();
})();
