// Pedidos Múltiples JS
// Uses App.onMount (backed by $.onmount) so it fires on every Turbolinks navigation
// that inserts matching elements — never uses DOMContentLoaded or $(document).ready.

// Resumen page: cupon apply/remove buttons (delegated, inside #resumen-multiple).
App.onMount('#resumen-multiple', function() {
  this.on('click', '.rm-aplicar-cupon-btn', function() {
    var pedidoId = $(this).data('pedido-id');
    var codigo = $('#cupon_codigo_input_' + pedidoId).val();
    if (!codigo) return;
    var tk = $('meta[name="csrf-token"]').attr('content');
    $.ajax({
      url: '/pedidos/' + pedidoId + '/aplicar_cupon',
      type: 'POST',
      dataType: 'script',
      data: 'cupon_codigo=' + encodeURIComponent(codigo) + '&authenticity_token=' + encodeURIComponent(tk) + '&utf8=✓'
    });
  });

  this.on('click', '.rm-quitar-cupon-btn', function(e) {
    e.preventDefault();
    var pedidoId = $(this).data('pedido-id');
    var tk = $('meta[name="csrf-token"]').attr('content');
    $.ajax({
      url: '/pedidos/' + pedidoId + '/quitar_cupon',
      type: 'DELETE',
      dataType: 'script',
      data: 'authenticity_token=' + encodeURIComponent(tk) + '&utf8=✓'
    });
  });
});

// Resumen page: single turno → auto-assign via PATCH, then reload.
App.onMount('[data-auto-assign-turno]', function() {
  var $el = $(this);
  var turnoId = $el.data('auto-assign-turno');
  var pedidoId = $el.data('pedido-id');
  if (!turnoId || !pedidoId) return;
  $.ajax({
    url: '/pedidos/' + pedidoId,
    method: 'PATCH',
    data: { pedido: { turno_entrega_id: turnoId } },
    headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
    success: function() { window.location.reload(); }
  });
});

// Resumen page: turno_entrega change → PATCH pedido, then reload.
App.onMount('[id^="turno_entrega_selector_"]', function() {
  this.on('change', function() {
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
});

// Resumen page: enviar_a change → PATCH pedido + show/hide direccion field.
$(document).off('change.pedidosMultiplesEnviarA', '[id^="enviar_a_selector_"]')
  .on('change.pedidosMultiplesEnviarA', '[id^="enviar_a_selector_"]', function() {
  var $sel = $(this);
  var val = $sel.val();
  var pedidoId = $sel.data('pedido-id');
  if (!pedidoId) return;

  var $wrap = $('#direccion-envio-wrap-' + pedidoId);
  if (val == '-1') {
    $wrap.show();
  } else {
    $wrap.hide();
    $sel.prop('disabled', true);
    $.ajax({
      url: '/pedidos/' + pedidoId,
      method: 'PATCH',
      data: { pedido: { enviar_a_id: val } },
      headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
      success: function() { $sel.prop('disabled', false); },
      error: function() {
        alert('Error al actualizar el destino de envío');
        $sel.prop('disabled', false);
      }
    });
  }
});

// Resumen page: direccion_envio blur → PATCH pedido.
App.onMount('[id^="direccion_envio_"]', function() {
  this.on('blur', function() {
    var $input = $(this);
    var pedidoId = $input.data('pedido-id');
    var dir = $input.val().trim();
    if (!pedidoId) return;
    $.ajax({
      url: '/pedidos/' + pedidoId,
      method: 'PATCH',
      data: { pedido: { enviar_a_id: -1, direccion_envio: dir } },
      headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
      error: function() { alert('Error al guardar la dirección.'); }
    });
  });
});

// Resumen page: horario change → PATCH pedido, then reload.
App.onMount('[id^="horario_selector_"]', function() {
  this.on('change', function() {
    var $sel = $(this);
    var horarioId = $sel.val();
    var pedidoId = $sel.data('pedido-id');
    if (!pedidoId) return;
    $sel.prop('disabled', true);
    $.ajax({
      url: '/pedidos/' + pedidoId,
      method: 'PATCH',
      data: { pedido: { horario_id: horarioId } },
      headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
      success: function() { window.location.reload(); },
      error: function() {
        alert('Error al actualizar el horario');
        $sel.prop('disabled', false);
      }
    });
  });
});

// Resumen page: "Aplicar a todos" buttons → PATCH the chosen value to every
// other pendiente pedido in the group, then reload.
$(document).off('click.pedidosMultiplesCopyAll', '.rm-copy-to-all')
  .on('click.pedidosMultiplesCopyAll', '.rm-copy-to-all', function(e) {
  e.preventDefault();
  var $btn = $(this);
  var field = $btn.data('field');
  var sourcePid = String($btn.data('pedido-id'));
  if (!field || !sourcePid) return;

  // Read current value from the source pedido's selector.
  var sourceSelector;
  if (field === 'turno_entrega_id') sourceSelector = '#turno_entrega_selector_' + sourcePid;
  else if (field === 'horario_id')  sourceSelector = '#horario_selector_' + sourcePid;
  else if (field === 'enviar_a_id') sourceSelector = '#enviar_a_selector_' + sourcePid;
  else return;

  var value = $(sourceSelector).val();
  if (value === null || value === '' || value === undefined) {
    alert('Primero seleccioná un valor para copiar.');
    return;
  }

  // Find all OTHER pedidos in the group (their selectors share the field prefix).
  var prefix = sourceSelector.replace(sourcePid, '').slice(0, -0); // keep selector pattern
  var selectorPattern;
  if (field === 'turno_entrega_id') selectorPattern = '[id^="turno_entrega_selector_"]';
  else if (field === 'horario_id')  selectorPattern = '[id^="horario_selector_"]';
  else if (field === 'enviar_a_id') selectorPattern = '[id^="enviar_a_selector_"]';

  var targetPedidoIds = [];
  $(selectorPattern).each(function() {
    var pid = String($(this).data('pedido-id'));
    if (pid && pid !== sourcePid) targetPedidoIds.push(pid);
  });

  if (!targetPedidoIds.length) return;

  if (!confirm('¿Aplicar este valor a los ' + targetPedidoIds.length + ' pedidos restantes del grupo?')) return;

  $btn.prop('disabled', true).html('<i class="mdi mdi-loading mdi-spin mr-1"></i>Aplicando...');

  var token = $('meta[name="csrf-token"]').attr('content');
  var requests = targetPedidoIds.map(function(pid) {
    var data = { pedido: {} };
    data.pedido[field] = value;
    return $.ajax({
      url: '/pedidos/' + pid,
      method: 'PATCH',
      data: data,
      headers: { 'X-CSRF-Token': token }
    });
  });

  $.when.apply($, requests).always(function() {
    window.location.reload();
  });
});

// Cart dropdown: edit-pedido links navigate natively (anchors carry
// data-turbolinks="false"). The previous Turbolinks.visit() override was
// racy under load — when Turbolinks dropped the visit (pending XHRs,
// Bootstrap dropdown close, asset contention) e.preventDefault() left the
// browser stuck on the current URL. Letting the browser handle the click
// (full nav, honored by data-turbolinks="false") is deterministic.
// Only intercept to short-circuit disabled state and to force a hard nav
// when a stale handler somewhere else might have called preventDefault.
$(document).off('click.pedidosMultiplesCartNav', '#pedido-en-curso .gbs-edit-link, #pedido-en-curso .boton-aceptar-pedido')
  .on('click.pedidosMultiplesCartNav', '#pedido-en-curso .gbs-edit-link, #pedido-en-curso .boton-aceptar-pedido', function(e) {
  if ($(this).hasClass('disabled')) { e.preventDefault(); return false; }

  // If anything upstream called preventDefault (or will), force navigation.
  // Using window.location.href guarantees a full page load that matches the
  // anchor's data-turbolinks="false" intent and cannot be swallowed by
  // Turbolinks' XHR pipeline.
  var href = $(this).attr('href');
  if (!href || href === '#' || href.indexOf('javascript:') === 0) return;
  e.preventDefault();
  window.location.href = href;
});

// ── Multi-fecha hint ──────────────────────────────────────────────────────────
// Shows below the fecha input after the first product is added to a pedido
// that is NOT yet in a group. Hides when group badges appear.
// Uses Motion One for an animated entrance.

App.onMount('#carga-pedidos', function() {
  var $hint = $('#multi-fecha-hint');
  var shown = false;

  function M() { return window.Motion || null; }

  function showHint() {
    if (shown) return;
    // Don't show if pedido is already in a group (badges visible)
    if ($('#grupo-badges-container .gbs-wrap').length) return;
    shown = true;
    var el = $hint[0];
    var inner = $hint.find('.mfh-inner')[0];
    var badge = $hint.find('.mfh-badge')[0];

    $hint.show();

    if (M()) {
      var animate = M().animate;
      var spring  = M().spring;
      // Entrance: slide up + fade
      animate(el,
        { opacity: [0, 1], transform: ['translateY(6px)', 'translateY(0)'] },
        { duration: 0.45, easing: spring({ stiffness: 280, damping: 22 }) }
      );
      // Badge pop-in with slight delay
      animate(badge,
        { transform: ['scale(0.5)', 'scale(1.12)', 'scale(1)'], opacity: [0, 1] },
        { duration: 0.5, delay: 0.18, easing: spring({ stiffness: 340, damping: 16 }) }
      );
      // Gentle pulse on the icon once
      var icon = $hint.find('.mfh-icon')[0];
      if (icon) {
        animate(icon,
          { transform: ['rotate(-8deg)', 'rotate(5deg)', 'rotate(0deg)'] },
          { duration: 0.55, delay: 0.3, easing: spring({ stiffness: 260, damping: 12 }) }
        );
      }
    } else {
      $hint.css({ opacity: 0 }).animate({ opacity: 1 }, 400);
    }
  }

  function hideHint() {
    if (!shown) return;
    if (M()) {
      var animation = M().animate($hint[0],
        { opacity: [1, 0], transform: ['translateY(0)', 'translateY(-4px)'] },
        { duration: 0.25, easing: [0.4, 0, 1, 1] }
      );
      var finish = function() { $hint.hide(); shown = false; };
      if (animation && typeof animation.then === 'function') {
        animation.then(finish);
      } else if (animation && animation.finished && typeof animation.finished.then === 'function') {
        animation.finished.then(finish);
      } else {
        window.setTimeout(finish, 260);
      }
    } else {
      $hint.fadeOut(200, function() { shown = false; });
    }
  }

  // Show after first product is added
  $(document).on('ajaxComplete.multifechahint', function() {
    var count = parseInt($('#total-seleccionados').text(), 10) || 0;
    if (count > 0 && !$('#grupo-badges-container .gbs-wrap').length) {
      showHint();
    } else if ($('#grupo-badges-container .gbs-wrap').length) {
      hideHint();
    } else if (count === 0) {
      hideHint();
    }
  });

  $(document).on('pedidos:cart-vaciado.multifechahint', hideHint);

  // Also hide if group badges are injected (AJAX cambiar_cuenta response)
  var observer = new MutationObserver(function() {
    if ($('#grupo-badges-container .gbs-wrap').length) hideHint();
  });
  var container = document.getElementById('grupo-badges-container');
  if (container) observer.observe(container, { childList: true, subtree: false });

  // Cleanup on Turbolinks navigation
  $(document).one('turbolinks:before-cache', function() {
    $(document).off('ajaxComplete.multifechahint');
    $(document).off('pedidos:cart-vaciado.multifechahint');
    observer.disconnect();
  });
});

// ── Group badge hover spring animation ────────────────────────────────────────
// Adds a subtle lift+scale on hover for each .gbs-tab using Motion spring.
App.onMount('#grupo-badges-container', function() {
  function M() { return window.Motion || null; }
  if (!M()) return;

  var animate = M().animate;
  var spring  = M().spring;

  $(this).on('mouseenter', '.gbs-tab', function() {
    animate(this.parentElement, // .gbs-tab-wrap
      { transform: ['translateY(0px) scale(1)', 'translateY(-3px) scale(1.02)'] },
      { duration: 0.35, easing: spring({ stiffness: 380, damping: 20 }) }
    );
  }).on('mouseleave', '.gbs-tab', function() {
    animate(this.parentElement,
      { transform: ['translateY(-3px) scale(1.02)', 'translateY(0px) scale(1)'] },
      { duration: 0.3, easing: spring({ stiffness: 320, damping: 24 }) }
    );
  });

  // Click: brief press-down feedback
  $(this).on('mousedown', '.gbs-tab', function() {
    animate(this, { transform: ['scale(1)', 'scale(0.97)'] },
      { duration: 0.12, easing: [0.4, 0, 1, 1] }
    );
  });
});

// ── Datepicker group-date highlights ────────────────────────────────────────
// Bootstrap-datepicker renders day cells with UTC millis in td[data-date]. Keep
// those cells highlighted for the pedidos currently present in the group.
App.onMount('#carga-pedidos', function() {
  function groupDateValues() {
    var raw = $('#grupo-badges-container .gbs-wrap').data('pedido-group-date-ms');
    if (!raw) return [];
    return raw.toString().split(',').filter(function(value) { return value.length > 0; });
  }

  function currentPedidoDateValue() {
    var raw = $('#grupo-badges-container .gbs-wrap').data('pedido-current-date-ms');
    return raw ? raw.toString() : null;
  }

  function refreshGroupDateHighlights() {
    var dates = groupDateValues();
    var currentDate = currentPedidoDateValue();
    $('.datepicker-days td.day').removeClass('pedido-group-date pedido-current-date');
    if (!dates.length) return;

    dates.forEach(function(dateValue) {
      $('.datepicker-days td.day[data-date="' + dateValue + '"]').addClass('pedido-group-date');
    });

    if (currentDate) {
      $('.datepicker-days td.day[data-date="' + currentDate + '"]').addClass('pedido-current-date');
    }
  }

  $(document)
    .off('show.pedidosGroupDates changeMonth.pedidosGroupDates changeYear.pedidosGroupDates', '#pedido_fecha')
    .on('show.pedidosGroupDates changeMonth.pedidosGroupDates changeYear.pedidosGroupDates', '#pedido_fecha', function() {
      window.setTimeout(refreshGroupDateHighlights, 0);
    });

  var container = document.getElementById('grupo-badges-container');
  var observer = new MutationObserver(refreshGroupDateHighlights);
  if (container) observer.observe(container, { childList: true, subtree: true, attributes: true });

  $(document).one('turbolinks:before-cache', function() {
    $(document).off('show.pedidosGroupDates changeMonth.pedidosGroupDates changeYear.pedidosGroupDates', '#pedido_fecha');
    observer.disconnect();
  });
});
