// Subscribe to ProcesosChannel on the pedidos index page.
// Shows a live progress banner during background import and reloads when done.
App.onMount('#pedidos-container', function() {
  if (typeof App === 'undefined' || !App.cable) return;

  // Show success banner after reload from a completed import
  var urlParams = new URLSearchParams(window.location.search);
  var importedCount = urlParams.get('imported');
  if (importedCount) {
    var container = document.getElementById('pedidos-container');
    if (container) {
      var successBanner = document.createElement('div');
      successBanner.style.cssText = 'margin-bottom: 15px;';
      successBanner.innerHTML = '<div class="alert alert-success alert-dismissible" role="alert">' +
        '<button type="button" class="close" data-dismiss="alert"><span>&times;</span></button>' +
        '<strong><i class="fa fa-check-circle"></i> Importación completada</strong> — ' +
        'Mostrando ' + importedCount + ' pedidos importados exitosamente.' +
        '</div>';
      container.insertBefore(successBanner, container.firstChild);
    }
  }

  if (App.pedidosImportSub) return; // Already subscribed

  App.pedidosImportSub = App.cable.subscriptions.create("ProcesosChannel", {
    connected: function() {
      console.log("Pedidos: connected to ProcesosChannel for import updates");
    },

    disconnected: function() {
      console.log("Pedidos: disconnected from ProcesosChannel");
    },

    received: function(data) {
      console.log("Pedidos import received:", data);
      if (data.type !== 'procesos_update') return;
      // Only handle PedidosImporter broadcasts
      if (data.proceso_tipo && data.proceso_tipo !== 'Pedidos::PedidosImporter') return;

      var banner = document.getElementById('import-progress-banner');
      if (!banner) {
        banner = document.createElement('div');
        banner.id = 'import-progress-banner';
        banner.style.cssText = 'margin-bottom: 15px; transition: all 0.3s;';
        var container = document.getElementById('pedidos-container');
        if (container) container.insertBefore(banner, container.firstChild);
      }

      if (data.estado === 'Error') {
        var errHtml = '<div class="alert alert-danger alert-dismissible" role="alert">';
        errHtml += '<button type="button" class="close" data-dismiss="alert"><span>&times;</span></button>';
        errHtml += '<strong><i class="fa fa-exclamation-triangle"></i> Error en importación</strong>';
        if (data.errores && data.errores.length > 0) {
          errHtml += '<ul class="mb-0 mt-2">';
          for (var i = 0; i < data.errores.length; i++) {
            errHtml += '<li>' + data.errores[i] + '</li>';
          }
          errHtml += '</ul>';
        }
        errHtml += '</div>';
        banner.innerHTML = errHtml;
      } else if (data.estado === 'Finalizado') {
        banner.innerHTML = '<div class="alert alert-success" role="alert">' +
          '<strong><i class="fa fa-check-circle"></i> Importación finalizada (100%)</strong> — Recargando pedidos...' +
          '</div>';
        // Reload with filters matching the import params
        setTimeout(function() {
          var params = data.params || {};
          var url = window.location.pathname;
          var qs = [];
          if (params.cliente_id) qs.push('q[cliente_ids]=' + params.cliente_id);
          if (params.fecha) qs.push('q[fecha_desde]=' + encodeURIComponent(params.fecha));
          if (params.fecha) qs.push('q[fecha_hasta]=' + encodeURIComponent(params.fecha));
          qs.push('imported=' + (data.pedidos_count || ''));
          window.location.href = url + '?' + qs.join('&');
        }, 1500);
      } else if (data.estado === 'Ejecutando') {
        var pje = data.pje || 0;
        banner.innerHTML = '<div class="alert alert-info" role="alert">' +
          '<strong><i class="fa fa-spinner fa-spin"></i> Importando pedidos...</strong> ' + pje + '% completado' +
          '<div class="progress mt-2" style="height: 8px;">' +
          '<div class="progress-bar progress-bar-striped progress-bar-animated" role="progressbar" ' +
          'style="width: ' + pje + '%" aria-valuenow="' + pje + '" aria-valuemin="0" aria-valuemax="100"></div>' +
          '</div></div>';
      } else if (data.estado === 'Pendiente') {
        banner.innerHTML = '<div class="alert alert-info" role="alert">' +
          '<i class="fa fa-clock-o"></i> Importación en cola, esperando inicio...' +
          '</div>';
      }
    }
  });
});
