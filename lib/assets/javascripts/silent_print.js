function blockPage() {
  if (!$('#page').data('blockUI.isBlocked')) {
    $('#page').block({message: ''});
    toast.warning({ message: 'Procesando Ticket, espere por favor...', duration: 5000 });
  }
}

function unblockPage() {
  $('#page').unblock();
  $('.growl-imprimiendo').fadeOut('slow');
}

// En la v77 le quitaron soporte al window.print() que se usa en el JS embebido en los PDF
function isChrome77() {
  var browser = browserInfo();
  return browser.name === 'Chrome' && browser.majorVersion >= 77;
}

function downloadFileAndEncodeInBase64(url) {
  return new Promise(function(resolve, reject) {
    var req = new XMLHttpRequest();
    req.open('GET', url, true);
    req.responseType = 'arraybuffer';

    req.onload = function(e) {
      if (req.status === 200) {
        var reader = new FileReader();
        reader.addEventListener('load', function() {
          var base64response = reader.result.split(',')[1];
          resolve(base64response);
        }, false);
        reader.readAsDataURL(new Blob([req.response]));
      } else {
        reject(Error(req.statusText));
      }
    };

    // Handle network errors
    req.onerror = function() { reject(Error("Network Error")); };

    req.send();
  });
}

function printWithIframe(url) {
  return new Promise(function(resolve, _) {
    $('#silentprint-container').remove();
    $('body').append("<iframe id='silentprint-container' src='" + url + "' frameborder='0' width='100px' height='100px' style='opacity: 0.001;' />");
    $('#silentprint-container').load(function() {
      // Espera hasta que cargue el pdf
      // Sin esto el iframe robaba el foco
      setTimeout(function() {
        resolve();
        $('input:focus').blur().focus().select();
      }, 300);
    });
  });
}

function printNormal(url) {
  window.open(url);
}

function printWithService(printServiceObj, url, opts) {
  opts = opts || {};
  return downloadFileAndEncodeInBase64(url)
    .then(function(pdf) { return printServiceObj.submit({url: 'file.pdf', file_content: pdf, type: opts.type}); })
    .then(function() { toast.success({ html: '¡Listo!<br><br>Ticket enviado a la impresora.' }); })
    .catch(function() { toast.error({ html: '¡Ocurrió un error!<br><br>No se puede enviar el ticket a la impresora.<br> Imprima manualmente.', duration: 7000 }); });
}

window.silentPrint = function(url, opts) {
  blockPage();
  console.log('[SilentPrint] Service:', printService.constructor.name || (printService._defaultPrinter !== undefined ? 'QZPrintService' : 'WebSocketPrinter'));
  printService.connect()
    .then(function() {
      console.log('[SilentPrint] Connected OK, printing...');
      return printWithService(printService, url, opts);
    })
    .catch(function(err) {
      console.error('[SilentPrint] Connection FAILED, falling back to browser print:', err);
      return isChrome77() ? printNormal(url) : printWithIframe(url);
    })
    .then(unblockPage);
  return false;
};

$(document).on('click', '.silentprint', function(e) {
  e.preventDefault();
  silentPrint($(this).attr('href'), {type: $(this).data('job-type')});
});
