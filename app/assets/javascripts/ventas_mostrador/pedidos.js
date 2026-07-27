var vmDelay = (function() {
  var timer = 0;
  return function(callback, ms) {
    if ($('#producto-anterior-vm').val() === $('#producto-actual-vm').val()) {
      clearTimeout(timer);
    }
    timer = setTimeout(callback, ms);
  };
})();

App.onMount('#index-venta-mostrador', function() {
  this.on('click', '#agregar-producto-vr', function() {
    $('#productos-rapidos').block();
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.ajax({
      url: '/ventas_mostrador/pedidos/' + $('#pedido-vm-id').data('id') + '/agregar',
      type: 'POST',
      dataType: 'script',
      data: $(this).serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓'
    });
    return false;
  });

  $("#buscador-vr #codigo").focus();

  // Auto-fill importe of first medio de pago when only one exists
  function autoFillSingleMedio() {
    var $rows = $('#medios-pago-rows .fields:visible');
    if ($rows.length === 1) {
      var $totalEl = $('#importe-total-container');
      if ($totalEl.length) {
        var totalText = $totalEl.text().replace(/[^0-9.,]/g, '').replace(/\./g, '').replace(',', '.');
        var total = parseFloat(totalText);
        if (!isNaN(total) && total > 0) {
          $rows.find('.medio-pago-importe').val(total.toFixed(2));
        }
      }
    }
  }

  // Observe product changes to auto-fill single medio importe
  $(document).ajaxComplete(function() {
    setTimeout(autoFillSingleMedio, 200);
  });

  this.shortcuts({
    'F8': function() { $('#boton-cancelar-vm')[0].click(); },
    'F10': function() { $('#boton-confirmar-pedido-vm')[0].click(); }
  });

  this.on('change', '#pedido_cuenta_id, #pedido_fecha', function() {
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.ajax({
      url: '/ventas_mostrador/pedidos/' + $('#pedido-vm-id').data('id') + '/cambiar_cuenta',
      type: 'POST',
      dataType: 'script',
      data: $(this).serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓'
    });
  });

  this.on('change', '.productos_solicitados_venta_mostrador .adicionador', function() {
    $(this).trigger('keyup');
  });

  this.on('click', '.productos_solicitados_venta_mostrador .remove_nested_fields', function() {
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    var $row = $(this).closest('tr');
    var p = $row.find('.adicionador');
    var productoid = p.length ? p.data('productoid') : $row.find('.peso-input').data('productoid');
    $.ajax({
      url: '/ventas_mostrador/pedidos/' + $('#pedido-vm-id').data('id') + '/actualizar_producto?cantidad=0&productoid=' + productoid,
      type: 'POST',
      dataType: 'script',
      data: 'authenticity_token=' + tk + '&utf8=✓',
      success: function() {
        $row.fadeOut();
      }
    });
    return false;
  });

  this.on('keydown', '#codigo', function(e) {
    if (e.keyCode === 13) {
      $('#agregar-producto-vr').click();
      e.preventDefault();
    }
  });

  this.on('keydown', '#s2id_producto_id', function(e) {
    if (e.keyCode === 13) {
      $('#agregar-producto-vr').click();
      e.preventDefault();
    }
  });

  this.on('keyup', '.productos_solicitados_venta_mostrador .adicionador', function() {
    var val = $('#pedido_pendiente_id_hidden').val();
    var c = $(this);
    $('#producto-anterior-vm').val($('#producto-actual-vm').val());
    $('#producto-actual-vm').val(c.data('productoid'));
    vmDelay(function() {
      var ca = parseInt(c.val());
      if (ca !== parseInt(c.attr('value'))) {
        c.attr('value', ca);
        var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
        var pesoInput = c.closest('tr').find('.peso-input');
        var pesoParam = pesoInput.length ? '&peso=' + pesoInput.val() : '';
        $.post('/ventas_mostrador/pedidos/' + $('#pedido-vm-id').data('id') + '/actualizar_producto.js?cantidad=' + c.val() + '&productoid=' + c.data('productoid') + pesoParam + '&authenticity_token=' + tk + '&utf8=✓', function() {
          if (ca <= 0) {
            c.closest('.fields').fadeOut();
          } else {
            c.effect('highlight', {}, 1000);
          }
          $("#importe-total-container").effect('highlight', {}, 250);
        });
      }
    }, 400);
  });

  // Peso modal: confirm button handler
  this.on('click', '#peso-modal-confirmar', function() {
    var productoId = $('#peso-modal-producto-id').val();
    var peso = parseFloat($('#peso-modal-input').val());
    if (!peso || peso <= 0) {
      $('#peso-modal-input').addClass('is-invalid').focus();
      return;
    }
    // Force-remove modal and backdrop synchronously to avoid transition race with AJAX response
    $('#peso-modal').removeClass('show').css('display', 'none');
    $('.modal-backdrop').remove();
    $('body').removeClass('modal-open').css({'padding-right': '', 'overflow': ''});
    $('#productos-rapidos').block();
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.ajax({
      url: '/ventas_mostrador/pedidos/' + $('#pedido-vm-id').data('id') + '/agregar_pesable',
      type: 'POST',
      dataType: 'script',
      data: 'producto_id=' + productoId + '&peso=' + peso + '&authenticity_token=' + tk + '&utf8=✓'
    });
  });

  // Peso modal: Enter key confirms
  this.on('keydown', '#peso-modal-input', function(e) {
    if (e.keyCode === 13) {
      e.preventDefault();
      $('#peso-modal-confirmar').click();
    }
  });

  // Clear invalid state when typing in peso modal
  this.on('input', '#peso-modal-input', function() {
    $(this).removeClass('is-invalid');
  });

  // Peso modal: ensure backdrop/body cleanup on any dismiss (cancel, X, ESC, backdrop click)
  // Bootstrap sometimes leaves the backdrop orphaned due to BS3/BS4 conflicts.
  this.on('hidden.bs.modal', '#peso-modal', function() {
    $('.modal-backdrop').remove();
    $('body').removeClass('modal-open').css({'padding-right': '', 'overflow': ''});
    $('#productos-rapidos').unblock();
    $('#peso-modal-input').removeClass('is-invalid').val('');
    $('#buscador-vr #codigo').focus();
  });

  // Peso input change in cart: debounced update
  this.on('change', '.productos_solicitados_venta_mostrador .peso-input', function() {
    var c = $(this);
    var pesoVal = parseFloat(c.val().replace(',', '.'));
    if (!pesoVal || pesoVal <= 0) return;
    var cantidadInput = c.closest('tr').find('.adicionador');
    var cantidad = cantidadInput.length ? cantidadInput.val() : '1';
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.post('/ventas_mostrador/pedidos/' + $('#pedido-vm-id').data('id') + '/actualizar_producto.js?cantidad=' + cantidad + '&productoid=' + c.data('productoid') + '&peso=' + pesoVal + '&authenticity_token=' + tk + '&utf8=✓', function() {
      c.effect('highlight', {}, 1000);
      $("#importe-total-container").effect('highlight', {}, 250);
    });
  });
});
