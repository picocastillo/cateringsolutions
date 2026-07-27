// Use document-level delegation so this works even if the deferred
// adds_on.js executes AFTER turbolinks:load fires (production-only race
// where App.onMount('body', ...) gets registered too late for the initial
// $.onmount scan to bind it). Document is always present.
$(document).off('click.tiendaSwitch', '.btn-tienda-switch, .selector-tienda')
           .on('click.tiendaSwitch', '.btn-tienda-switch, .selector-tienda', function(e) {
  e.preventDefault();
  var tk = $('meta[name="csrf-token"]').attr("content");
  var tiendaId = $(this).data('tienda-id') || $(this).attr('id');
  $.ajax({
    url: '/tiendas/cambiar_tienda_activa',
    method: 'POST',
    data: { tienda_activa_id: tiendaId, authenticity_token: tk },
    dataType: 'json',
    success: function(res) {
      window.location.href = res.redirect_url || '/inicio';
    },
    error: function() {
      window.location.href = '/inicio';
    }
  });
});

App.onMount('body', function() {
  this.on('click', '.selector-local', function() {
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    var localId = $(this).data('local-id');
    $.post('/tiendas/cambiar_local_activo.js?local_id=' + localId + '&authenticity_token=' + tk + '&utf8=✓', function() {
      location.reload();
    });
  });
});

App.onMount('#new-usuario, #edit-usuario', function() {
  this.on('change', '#usuario_cuenta_id', function() {
    if ($(this).val()) {
      $('.roles-admin').hide();
      $('#roles-cliente').show();
      $('.usuario_telefono').removeClass('col-sm-6').addClass('col-sm-4');
    } else {
      $('#roles-cliente').hide();
      $('.roles-admin').show();
      $('.usuario_telefono').removeClass('col-sm-4').addClass('col-sm-6');
    }
  });

  $('#usuario_cuenta_id').change();
});

function renderProductosFavoritosChart(canvas) {
  if (typeof Chart === 'undefined') return;
  var labels = JSON.parse(canvas.dataset.labels || '[]');
  var datos = JSON.parse(canvas.dataset.datos || '[]');
  if (!labels.length) return;
  new Chart(canvas.getContext('2d'), {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [{
        label: 'Cantidad pedida',
        data: datos,
        backgroundColor: 'rgba(0, 158, 251, 0.6)',
        borderColor: '#009efb',
        borderWidth: 1
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: { x: { beginAtZero: true, ticks: { stepSize: 1 } } }
    }
  });
}

App.onMount('#show-usuario #chart-productos-favoritos', function() {
  renderProductosFavoritosChart(this[0]);
});

App.onMount('#show-usuario #chart-productos-favoritos-3m', function() {
  renderProductosFavoritosChart(this[0]);
});
