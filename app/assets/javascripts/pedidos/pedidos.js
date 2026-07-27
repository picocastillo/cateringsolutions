var delay = (function() {
  var timer = null;
  return function(callback, ms) {
    if (timer != null) {
      clearTimeout(timer);
    }
    timer = setTimeout(callback, ms);
  };
})();

function eventos_carrito(sumador, refresh) {
  var o = sumador.parent().parent().find('.cantidad');
  var val = $('#pedido_pendiente_id_hidden').val();
  // Skip toast confirmations for +/- clicks inside the cart panel itself —
  // the user is staring at the cart, the row updates in place, no need to nag.
  var silent = sumador.closest('#pedido-en-curso').length > 0;
  comprar(val, o, sumador, refresh, silent);
  return false;
}

function resaltar(id) {
  $(id).effect('highlight', {}, 3000);
}

function initProductSliders() {
  document.querySelectorAll('.swiper:not(.swiper-initialized)').forEach(function(node) {
    if ($(node).closest('.panel-content.hide').length > 0) return;

    var singleCol = node.classList.contains('swiper-single-col');
    // On desktop (≥768px), singleCol resets to 1 slide; multiCol shows 2+
    // On mobile (<768px), default slidesPerView (1.12) applies — peek the next card
    var breakpoints = singleCol ? {
      768: { slidesPerView: 1, spaceBetween: 0 }
    } : {
      768:  { slidesPerView: 2, spaceBetween: 10 },
      1100: { slidesPerView: 3, spaceBetween: 10 },
      1800: { slidesPerView: 4, spaceBetween: 10 },
      2200: { slidesPerView: 5, spaceBetween: 10 },
      2800: { slidesPerView: 6, spaceBetween: 10 }
    };

    var swiper = new Swiper(node, {
      slidesPerView: 1.12,  // peek ~12% of the next card on mobile
      spaceBetween: 8,
      speed: 300,
      cssMode: false,       // must be false for fractional slidesPerView to work
      touchRatio: 0.7,  // 0-1, lower = slower drag response
      longSwipesRatio: 0.5,  // threshold to trigger slide change
      grabCursor: true,
      preventClicks: true,
      preventClicksPropagation: true,
      touchEventsTarget: 'wrapper',
      noSwiping: true,
      noSwipingSelector: 'a, button, input, select, textarea, .fav-container',
      freeMode: {
        enabled: !mobile(),
        momentum: true,
        momentumBounce: true
      },
      pagination: {
        el: node.querySelector('.swiper-pagination'),
        clickable: true,
        dynamicBullets: true
      },
      navigation: {
        nextEl: node.querySelector('.swiper-button-next'),
        prevEl: node.querySelector('.swiper-button-prev')
      },
      breakpoints: breakpoints,
      roundLengths: true,
      on: {
        touchStart: function() { node.classList.add('swiping'); },
        sliderMove: function() { node.classList.add('swiping'); },
        slideChangeTransitionStart: function() { node.classList.add('swiping'); },
        transitionEnd: function() { node.classList.remove('swiping'); }
      }
    });

    $('.hide-please').addClass('hide');
  });
}

function resaltar_leve(id) {
  $(id).effect('highlight', {}, 150);
}

function comprar(val, c, sumador, refresh, silent) {
  console.log(c);
  var suma = parseInt(sumador.attr('data-suma'));

  // Check stock availability
  var stock_activo = c.data('stock-activo');
  var stock_disponible = parseInt(c.data('stock-disponible'));
  var cantidad_actual = parseInt(c.val());
  var nueva_cantidad = cantidad_actual + suma;

  // If stock control is enabled and trying to add more
  if (stock_activo && suma > 0) {
    if (isNaN(stock_disponible) || stock_disponible < 1) {
      toast.stockError({
        id: c.data('productoid'),
        name: c.data('nombre'),
        image: c.data('imagen'),
        available: 0,
        mode: 'sin_stock'
      });
      return false;
    }
    if (nueva_cantidad > stock_disponible) {
      toast.stockError({
        id: c.data('productoid'),
        name: c.data('nombre'),
        image: c.data('imagen'),
        available: stock_disponible,
        requested: nueva_cantidad
      });
      return false;
    }
  }

  if (parseInt(c.val()) + suma > -1) {
    var formatter = new Intl.NumberFormat('es-AR', {minimumFractionDigits: 2, maximumFractionDigits: 2});
    c.val(parseInt(c.val()) + suma);
    var total_actual = parseFloat($("#total-pedido-pendiente").html().replace('$', '').replace('.', '').replace(',', '.'));
    if (!total_actual) {
      total_actual = 0;
    }
    $("#total-pedido-pendiente").html('$' + formatter.format(total_actual + (suma * parseFloat(c.data('precio')))));
    if (parseInt(c.val()) > 0) {
      $('#input_cantidad_' + c.data('productoid')).addClass('mayorcero');
    } else {
      $('#input_cantidad_' + c.data('productoid')).removeClass('mayorcero');
    }
    var importe = formatter.format(parseFloat(c.data('precio')) * parseInt(c.val()));
    if (refresh) {
      $("#total-seleccionados").html(parseInt($("#total-seleccionados").html()) + suma);
      $("#total-producto-solicitado-" + c.data('productoid')).html('$' + importe);
      var pd = $('#input_cantidad_' + c.data('productoid'));
      if (pd) {
        pd.val(c.val());
        resaltar_leve('#cantidad_producto_' + c.data('productoid') + ' .cantidad');
        if (pd.val() > 0) {
          pd.addClass('mayorcero');
        } else {
          pd.removeClass('mayorcero');
        }
      }
    }

    var nuevaCantidad = parseInt(c.val());
    var totalProducto = parseFloat(c.data('precio')) * nuevaCantidad;
    if (!silent) {
      // Compute updated day total client-side immediately (no AJAX wait)
      var precio = parseFloat(c.data('precio'));
      var $activeTab = $('.gbs-tab--active .gbs-tab__total');
      var newDayTotal = null;
      if ($activeTab.length) {
        // Group pedido: compute from badge tab and update it in place
        var rawDay = $activeTab.text().trim().replace(/[$]/g, '').replace(/\./g, '').replace(',', '.');
        var parsedDay = parseFloat(rawDay);
        if (!isNaN(parsedDay)) {
          var updatedDay = parsedDay + suma * precio;
          newDayTotal = '$' + formatter.format(updatedDay);
          $activeTab.text(newDayTotal);
        }
      } else {
        // Single pedido: #total-pedido-pendiente was already updated above
        newDayTotal = $('#total-pedido-pendiente').text().trim() || null;
      }
      toast.product({
        id: c.data('productoid'),
        name: c.data('nombre'),
        image: c.data('imagen'),
        qty: nuevaCantidad,
        qtyDelta: suma,
        total: '$' + formatter.format(totalProducto),
        removed: nuevaCantidad === 0,
        cartTotal: newDayTotal
      });
    }

    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    var pid = c.data('productoid');
    var url = '/pedidos/' + val + '/actualizar_producto';
    var data = c.serializeClosestForm() + '&refresh=' + refresh + '&authenticity_token=' + tk + '&utf8=✓';
    App.cartXhr.send(pid, url, data, function() {
      $(".message-center").slimScroll({
        position: "right",
        size: "5px",
        color: "#dcdcdc",
        allowPageScroll: false
      });
    });
  }
}

App.onMount('#inicio', function() {
  this.on('change', '#q_fecha, .seleccion-cliente', function() {
    $('.search-btn').click();
  });
});

var _footerAggregatesXhr = null;

function loadFooterAggregates(basePath) {
  if (_footerAggregatesXhr) { _footerAggregatesXhr.abort(); }
  var params = $('#new_q').length ? $('#new_q').serialize() : '';
  var url = basePath + '/footer_aggregates?' + params;
  _footerAggregatesXhr = $.getJSON(url).done(function(data) {
    var formatter = new Intl.NumberFormat('es-AR', {minimumFractionDigits: 2, maximumFractionDigits: 2});
    if ($('#footer-pedidos-count').length) { $('#footer-pedidos-count').text(data.pedidos_count); }
    if ($('#footer-cantidad-total').length) { $('#footer-cantidad-total').text(data.cantidad_total); }
    if ($('#footer-importe-total').length) { $('#footer-importe-total').text('$' + formatter.format(data.importe_total)); }
  }).always(function() { _footerAggregatesXhr = null; });
}

App.onMount('#index-pedidos #pedidos-container', function() {
  $('.readmoreable').readmore();
  loadFooterAggregates('/pedidos');
});

App.onMount('#index-venta-mostrador #pedidos-container', function() {
  $('.readmoreable').readmore();
  loadFooterAggregates('/ventas_mostrador/pedidos');
});

App.onMount('#index-carga-simple', function() {
  this.on('change', '#pedido_tipo_pedido', function() {
    if ($(this).val() === '1') {
      $('.pedido_cuenta_id, .pedido_para_id').addClass('hide');
      $('.pedido_usuario_id').removeClass('hide');
    } else {
      $('.pedido_usuario_id').addClass('hide');
      $('.pedido_cuenta_id, .pedido_para_id').removeClass('hide');
    }
  });

  this.on('change', '#pedido_cuenta_id', function() {
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.post('/cargas_simples/pedidos/cambiar_cuenta', $(this).serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓');
  });

  this.on('change', '#pedido_enviar_a_id', function() {
    if ($(this).val() === '-1') {
      $('#wraper-direccion').removeClass('hide');
    } else {
      $('#wraper-direccion').addClass('hide');
    }
  });
});

App.onMount('#show-pedido #preference-container', function() {
  $('#preference-container').block();
  var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
  $.ajax({
    url: '/pedidos/' + $('#preference-container').data('pid') + '/generar_pago_ml',
    type: 'POST',
    dataType: 'script',
    data: '&authenticity_token=' + tk + '&utf8=✓'
  }).catch(function(err) {
    $('.mercadopago-button').attr("disabled", true);
    console.log('ERROR DE MERCADOPAGO:', err);
  });
});

// Re-fire generar_pago_ml AJAX after option fields are persisted, so the MP
// button + validation hint refresh based on the new pedido state.
function refireGenerarPagoMl() {
  var $pc = $('#preference-container');
  if (!$pc.length) return;
  $pc.block();
  // Reset disabled placeholder and hide previous validation hint while we wait.
  $pc.html('<button type="submit" class="mercadopago-button-disabled" disabled>Pagar con Mercadopago</button>');
  $('#mp-payment-validation-hint').hide();
  var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
  $.ajax({
    url: '/pedidos/' + $pc.data('pid') + '/generar_pago_ml',
    type: 'POST',
    dataType: 'script',
    data: '&authenticity_token=' + tk + '&utf8=✓'
  }).catch(function(err) {
    $('.mercadopago-button').attr("disabled", true);
    console.log('ERROR DE MERCADOPAGO:', err);
  });
}

// PATCH option fields on change and re-fire generar_pago_ml so the MP preference
// reflects the new turno / enviar_a / horario / direccion.
function patchPedidoAndRefireMp(pedidoId, attrs) {
  return $.ajax({
    url: '/pedidos/' + pedidoId,
    method: 'PATCH',
    data: { pedido: attrs },
    headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
  }).done(function() {
    if ($('#show-pedido #preference-container').length) {
      refireGenerarPagoMl();
    }
  });
}

App.onMount('#show-pedido', function() {
  if ($('#pedido_enviar_a_id').length) {
    this.on('change', '#pedido_enviar_a_id', function() {
      var pid = $('#preference-container').data('pid');
      if ($(this).val() === '-1') {
        $('#wraper-direccion').removeClass('hide');
        $('.total-simple').addClass('hide');
        $('.total-con-envio').removeClass('hide');
        // Persist envío a domicilio immediately so the pedido is never left as
        // "enviar a la empresa" while the user is still typing the address.
        // The MP button stays disabled (server-side validation) until a valid
        // direccion is provided, so we don't depend on the blur handler firing.
        if (pid) {
          var dir = ($('#pedido_direccion_envio').val() || '').trim();
          patchPedidoAndRefireMp(pid, { enviar_a_id: -1, direccion_envio: dir });
        }
      } else {
        $('#wraper-direccion').addClass('hide');
        $('.total-con-envio').addClass('hide');
        $('.total-simple').removeClass('hide');
        // Persist enviar_a_id and refresh MP preference
        if (pid) { patchPedidoAndRefireMp(pid, { enviar_a_id: $(this).val() }); }
      }
    });

    // Initialise display state from the current selection WITHOUT calling
    // patchPedidoAndRefireMp. The initial generar_pago_ml AJAX is already
    // fired by App.onMount('#show-pedido #preference-container'). Triggering
    // patchPedidoAndRefireMp here would send a second concurrent request,
    // and both async co.render() calls would target the same
    // '#mp-boton-container' ID, inserting two MP buttons (regression fix).
    (function initEnviarADisplay() {
      var val = $('#pedido_enviar_a_id').val();
      if (val === '-1') {
        $('#wraper-direccion').removeClass('hide');
        $('.total-simple').addClass('hide');
        $('.total-con-envio').removeClass('hide');
      } else {
        $('#wraper-direccion').addClass('hide');
        $('.total-con-envio').addClass('hide');
        $('.total-simple').removeClass('hide');
      }
    })();

    // Persist direccion_envio when user blurs the input (only relevant when
    // enviar_a_id == -1, i.e. domicilio particular).
    this.on('blur', '#pedido_direccion_envio', function() {
      var pid = $('#preference-container').data('pid');
      var dir = ($(this).val() || '').trim();
      if (pid && dir) {
        patchPedidoAndRefireMp(pid, { enviar_a_id: -1, direccion_envio: dir });
      }
    });

    this.on('click', '#confirmar_pedido', function() {
      var horario = '';
      var turno = '';
      if ($('#pedido_horario_id').val()) {
        horario = '&horario_id=' + $('#pedido_horario_id').val();
      }
      if ($('#turno_entrega_selector').val()) {
        turno = '&turno_entrega_id=' + $('#turno_entrega_selector').val();
      }
      if ($('#pedido_direccion_envio').val()) {
        $(this).attr('href', $(this).attr('href') + '?enviar_a_id=' + $('#pedido_enviar_a_id').val() + '&direccion=' + $('#pedido_direccion_envio').val() + horario + turno);
      } else {
        $(this).attr('href', $(this).attr('href') + '?enviar_a_id=' + $('#pedido_enviar_a_id').val() + horario + turno);
      }
    });
  } else {
    this.on('click', '#confirmar_pedido', function() {
      var params = '';
      var sep = '?';
      if ($('#pedido_horario_id').val()) {
        params += sep + 'horario_id=' + $('#pedido_horario_id').val();
        sep = '&';
      }
      if ($('#turno_entrega_selector').val()) {
        params += sep + 'turno_entrega_id=' + $('#turno_entrega_selector').val();
        sep = '&';
      }
      if (params) {
        $(this).attr('href', $(this).attr('href') + params);
      }
    });
  }

  // Turno selector change: PATCH pedido and reload (turno may filter category visibility).
  this.on('change', '#turno_entrega_selector', function() {
    var $sel = $(this);
    var turnoId = $sel.val();
    var pedidoId = $sel.data('pedido-id');
    if (!turnoId || !pedidoId) return;
    $sel.prop('disabled', true);
    $.ajax({
      url: '/pedidos/' + pedidoId,
      method: 'PATCH',
      data: { pedido: { turno_entrega_id: turnoId } },
      headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
      success: function() { window.location.reload(); },
      error: function() {
        alert('Error al actualizar el turno de entrega');
        $sel.prop('disabled', false);
      }
    });
  });

  // Horario selector change: PATCH and refresh MP preference.
  this.on('change', '#pedido_horario_id', function() {
    var pid = $('#preference-container').data('pid');
    if (pid && $(this).val()) {
      patchPedidoAndRefireMp(pid, { horario_id: $(this).val() });
    }
  });

  this.on('click', '#aplicar_cupon_btn', function() {
    var codigo = $('#cupon_codigo_input').val();
    if (!codigo) { return; }
    var pedidoId = $(this).data('pedido-id');
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.ajax({
      url: '/pedidos/' + pedidoId + '/aplicar_cupon',
      type: 'POST',
      dataType: 'script',
      data: 'cupon_codigo=' + encodeURIComponent(codigo) + '&authenticity_token=' + tk + '&utf8=✓'
    });
  });

  this.on('click', '#quitar_cupon_btn', function(e) {
    e.preventDefault();
    var pedidoId = $(this).data('pedido-id');
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.ajax({
      url: '/pedidos/' + pedidoId + '/quitar_cupon',
      type: 'DELETE',
      dataType: 'script',
      data: 'authenticity_token=' + tk + '&utf8=✓'
    });
  });
});

App.onMount('#index-carga-simple', function() {
  this.on('change', '.seleccion-usuario, #pedido_fecha', function() {
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.post('/cargas_simples/pedidos/cambiar_usuario', $(this).serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓');
  });
});

// Lazy-load "Nuestras opciones del día" panel after window is ready. The
// placeholder ships with just a spinner; this onMount fires on initial render
// AND every time #opciones-del-dia is re-injected (e.g. by cambiar_cuenta.js.erb),
// because App.onMount re-runs over freshly inserted DOM via $.onmount(). The
// data attribute is removed after kicking off the request so we don't double-fire.
App.onMount('#opciones-del-dia[data-pedido-id]', function() {
  var $el = $(this);
  var pedidoId = $el.data('pedido-id');
  if (!pedidoId) return;
  $el.removeAttr('data-pedido-id');
  // Defer until the browser is idle so it doesn't block initial paint of the
  // products listado / cart.
  var fire = function() {
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr('content'));
    $.ajax({
      url: '/pedidos/' + pedidoId + '/productos_diarios_panel',
      type: 'GET',
      dataType: 'script',
      data: 'authenticity_token=' + tk
    });
  };
  if ('requestIdleCallback' in window) {
    requestIdleCallback(fire, { timeout: 1500 });
  } else {
    setTimeout(fire, 50);
  }
});

App.onMount('#new-pedido .producto-venta [data-toggle="tooltip"]', function() {
  this.tooltip({ container: 'body' });

  // Close other tooltips when opening a new one, auto-close after 6s
  this.on('show.bs.tooltip', function() {
    $('#new-pedido .producto-venta [data-toggle="tooltip"]').not(this).tooltip('hide');
  });
  this.on('shown.bs.tooltip', function() {
    var el = $(this);
    clearTimeout(el.data('tooltip-timer'));
    el.data('tooltip-timer', setTimeout(function() { el.tooltip('hide'); }, 20000));
  });
  this.on('hide.bs.tooltip', function() {
    clearTimeout($(this).data('tooltip-timer'));
  });
});

// Close product tooltips on click outside
$(document).on('click', function(e) {
  if (!$(e.target).closest('[data-toggle="tooltip"]').length && !$(e.target).closest('.tooltip').length) {
    $('#new-pedido .producto-venta [data-toggle="tooltip"]').tooltip('hide');
  }
});

// Remove orphaned tooltip divs on AJAX content refresh
$(document).on('ajaxComplete', function() {
  $('body > .tooltip').remove();
});

// Reads the pedido's *actual* state (usuario pre.id + cuenta selected value) and
// enforces the correct value for the "Para" select (#pedido_tipo_pedido) together
// with the matching field visibility.  Called by App.onMount('#new-pedido') so it
// runs on every Turbolinks navigation, fixing any stale Turbolinks cache or plugin
// that may have reset the select back to "Usuario".
function applyTipoPedidoUI() {
  var $tipoPedido = $('#pedido_tipo_pedido');
  if (!$tipoPedido.length) return;

  var usuarioPre = $('#pedido_usuario_id').data('pre');
  var hasUsuario  = !!(usuarioPre && usuarioPre.id != null);
  var hasCuenta   = !!$('#pedido_cuenta_id').val();

  if (!hasUsuario && hasCuenta) {
    $tipoPedido.val('2');
    $('.pedido_usuario_id').addClass('hide');
    $('.pedido_cuenta_id, .pedido_para_id').removeClass('hide');
  } else {
    $tipoPedido.val('1');
    $('.pedido_cuenta_id, .pedido_para_id').addClass('hide');
    $('.pedido_usuario_id').removeClass('hide');
  }
}

App.onMount('#new-pedido', function() {
  // ── Initialise Para (tipo_pedido) on every mount ──
  applyTipoPedidoUI();

  $(window).on('scroll', function() {
    var cats = $('#cargar-panels-later').data('cats');
    if (cats) {
      delay(function() {
        cats = $('#cargar-panels-later').data('cats');
        if (cats) {
          $('#cargar-panels-later').removeData('cats');
          var more_posts_url = '/pedidos/' + $('#pedido_pendiente_id_hidden').val() + '/late_pannels' + '?cats=' + cats;
          if (more_posts_url && $(window).scrollTop() > $(document).height() - $(window).height() - 1000) {
            $('#cargar-panels-later').removeClass('hide');
            $.getScript(more_posts_url);
          }
        }
      }, 150);
    }
  });

  this.on('change', '#pedido_tipo_pedido', function() {
    if ($(this).val() === '1') {
      $('.pedido_cuenta_id, .pedido_para_id').addClass('hide');
      $('.pedido_usuario_id').removeClass('hide');
      // Clear cuenta selection when switching to Usuario mode
      $('#pedido_cuenta_id').val('').trigger('change.select2');
    } else {
      $('.pedido_usuario_id').addClass('hide');
      $('.pedido_cuenta_id, .pedido_para_id').removeClass('hide');
      // Clear usuario selection when switching to Cuenta mode
      $('#pedido_usuario_id').select2('val', '');
    }
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.ajax({
      url: '/pedidos/' + $('#pedido_pendiente_id_hidden').val() + '/cambiar_cuenta',
      type: 'POST',
      dataType: 'script',
      data: $(this).serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓'
    });
  });

  this.on('click', '#box.banner-gradient #close', function() {
    $('#mensaje-bievenida-container').fadeOut('fast');
  });

  this.on('click', '#box.banner-gradient a', function() {
    document.getElementById('panel-bebida_').scrollIntoView();
    return false;
  });

  this.on('change', '#pedido_cuenta_id', function() {
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.ajax({
      url: '/pedidos/' + $('#pedido_pendiente_id_hidden').val() + '/cambiar_cuenta',
      type: 'POST',
      dataType: 'script',
      data: $(this).serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓'
    });
  });

  this.on('click', '.producto-venta .cambiadores-cantidad', function() {
    return eventos_carrito($(this), false);
  });

  this.on('change select2-removed', '.seleccion-usuario, #pedido_usuario_id, #pedido_fecha', function() {
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.ajax({
      url: '/pedidos/' + $('#pedido_pendiente_id_hidden').val() + '/cambiar_cuenta',
      type: 'POST',
      dataType: 'script',
      data: $(this).serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓',
      success: function() {
        if ($('#resaltar-menues').length) {
          resaltar('#tablas-menues');
        }
      }
    });
  });

  this.on('change', '#categoria-selector', function() {
    $('#listado-de-productos').html('');
    $('#cargar-productos').show();
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    $.post('/pedidos/' + $('#pedido_pendiente_id_hidden').val() + '/cambiar_categoria', $(this).serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓');
  });

  this.on('keyup', '#pedido_busqueda', function() {
    var val = $('#pedido_pendiente_id_hidden').val();
    var c = $(this);
    delay(function() {
      var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
      $('#listado-de-productos').html('');
      $('#cargar-productos').show();
      $.post('/pedidos/' + val + '/cambiar_categoria', c.serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓', function() {
        c.effect('highlight', {}, 250);
      });
    }, 2000);
  });

  this.on('search', '#pedido_busqueda', function() {
    var val = $('#pedido_pendiente_id_hidden').val();
    var c = $(this);
    delay(function() {
      var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
      $('#listado-de-productos').html('');
      $('#cargar-productos').show();
      $.post('/pedidos/' + val + '/cambiar_categoria', c.serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓', function() {
        c.effect('highlight', {}, 250);
      });
    }, 1500);
  });

  this.on('click', '#listado-de-productos .fav-container', function() {
    var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
    toast.saved();
    var $star = $(this).find('i.fa-star');
    if ($(this).hasClass('active')) {
      $(this).removeClass('active');
      $(this).attr('title', 'Agregar a Favoritos');
      $star.removeClass('active');
    } else {
      $(this).addClass('active');
      $(this).attr('title', 'Quitar de Favoritos');
      $star.addClass('active');
    }
    var productoid = $(this).closest('.producto-venta').find('.productoid').val();
    $.ajax({url: '/productos/' + productoid + '/favorito.js' + '?authenticity_token=' + tk + '&utf8=✓', type: 'PUT', success: function() { return false; }});
  });

  $('#pedido-en-curso #continuar-compra').attr('href', 'JavaScript:void(0);');
  initProductSliders();
});

App.onMount('body', function() {
  this.on('click', '#menu-carga-flotante .adicionador-menu', function() {
    return eventos_carrito($(this), true);
  });

  this.on('click', '#pedido-en-curso .item', function(e) {
    if ($(e.target).closest('.gbs-edit-link').length) return;
    return false;
  });

  this.on('click', '.vaciar-pedido', function(e) {
    if (confirm('Desea vaciar el Carrito?')) {
      $('.transitionable').block();
      $('.listado-eliminable').remove();
      $('#cargar-productos').show();
      $('#cachincachin').html('<span id="total-pedido-pendiente"></span> <i class="mdi mdi-cart"></i><div class="notify">');
      toast.success('Se ha vaciado el Carrito.');
      $('#cart-container').effect('highlight', {color: '#d6d6d6'}, 1000);
      var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
      $.ajax({
        url: '/pedidos/' + $('#pedido_pendiente_id_hidden').val() + '/actualizar_desde_carrito',
        type: 'POST',
        dataType: 'script',
        data: $(this).serializeClosestForm() + '&vaciar_carrito=true' + '&authenticity_token=' + tk + '&utf8=✓'
      });
    } else {
      return false;
    }
  });

  this.on('click', '.sumador', function() {
    eventos_carrito($(this), true);
    return false;
  });
});

// Headroom-style sticky "Ir al Carrito" button (appears from top when original is off-screen)
App.onMount('#carga-pedidos #boton-compra', function() {
  var original = this[0]; // unwrap jQuery element
  if (!original) return;

  // Remove any previous sticky (turbolinks navigation)
  var prev = document.getElementById('boton-compra-sticky');
  if (prev) prev.remove();

  // Create the fixed clone
  var sticky = document.createElement('div');
  sticky.id = 'boton-compra-sticky';
  var primaryBtn = original.querySelector('.modern-primary-button');
  if (!primaryBtn) return;
  sticky.innerHTML = primaryBtn.outerHTML;
  document.body.appendChild(sticky);

  // Keep the clone's content in sync when the original is updated via AJAX
  var observer = new MutationObserver(function() {
    var btn = original.querySelector('.modern-primary-button');
    if (btn) sticky.innerHTML = btn.outerHTML;
  });
  observer.observe(original, { childList: true, subtree: true });

  var TOPBAR_HEIGHT = 64;

  var scrollHandler = function() {
    var originalRect = original.getBoundingClientRect();
    // Anticipate by topbar height: trigger when button is about to go behind the navbar
    var originalVisible = originalRect.bottom > TOPBAR_HEIGHT && originalRect.top < window.innerHeight;

    if (originalVisible) {
      // Original button still visible below topbar — hide sticky
      sticky.classList.remove('headroom--pinned');
    } else {
      // Original button hidden behind/above topbar — show sticky
      sticky.classList.add('headroom--pinned');
    }
  };

  window.addEventListener('scroll', scrollHandler, { passive: true });

  // Cleanup on turbolinks navigation
  $(document).one('turbolinks:before-render', function() {
    window.removeEventListener('scroll', scrollHandler);
    sticky.remove();
  });
});
