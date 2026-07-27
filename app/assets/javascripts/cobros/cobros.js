var cobrosDelay = (function() {
  var timer = 0;
  return function(callback, ms) {
    if ($('#producto-anterior-vm').val() === $('#producto-actual-vm').val()) {
      clearTimeout(timer);
    }
    timer = setTimeout(callback, ms);
  };
})();

App.onMount('#new-recibo', function() {
  this.on('change', '#recibo_cuenta_id', function() {
    $('#recibo-form').block();
    $.post("/cobros/afectaciones_cambio_cuenta.js", $(this).serializeClosestForm());
  });

  this.on('keyup', '.efectivos .recibo_efectivos_importe input, .retenciones .recibo_retenciones_importe input', function() {
    var c = $(this);
    cobrosDelay(function() {
      var ca = parseInt(c.val());
      if (ca !== parseInt(c.attr('value'))) {
        c.attr('value', ca);
        var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
        $('#recibo-form').block();
        $.post("/cobros/afectaciones.js", c.serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓');
      }
    }, 1000);
  });

  this.on('change', '.efectivos .recibo_efectivos_importe input, .retenciones .recibo_retenciones_importe input', function() {
    $(this).trigger('keyup');
  });

  this.on('keyup', '.afectaciones input.importe', function() {
    var c = $(this);
    cobrosDelay(function() {
      var ca = parseInt(c.val());
      if (ca !== parseInt(c.attr('value'))) {
        c.attr('value', ca);
        var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
        $('#recibo-form').block();
        $.post("/cobros/afectaciones.js", c.serializeClosestForm() + '&authenticity_token=' + tk + '&utf8=✓');
      }
    }, 1000);
  });

  this.on('change', '.afectaciones input.importe', function() {
    $(this).trigger('keyup');
  });
});
