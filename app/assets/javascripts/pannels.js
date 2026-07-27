$(document).on('click', '.panel-toggle', function() {
  var content = $(this).closest('.panel').find('.panel-content');
  var nombre = $(this).parent().parent().parent().find('.id_panel').val();
  if (content.is(':visible')) {
    content.fadeOut(100);
    $(this).text('Mostrar');
    if (nombre) {
      toast.saved();
      var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
      $.ajax({url: '/cuenta/actualizar_preferencias?nombre=togle_' + nombre + '&authenticity_token=' + tk + '&utf8=✓', type: 'POST', success: function() { return false; }});
    }
  } else {
    content.fadeIn(200);
    $(this).text('Ocultar');
    if (nombre) {
      toast.saved();
      var tk = encodeURIComponent($('meta[name="csrf-token"]').attr("content"));
      $.ajax({url: '/cuenta/actualizar_preferencias?nombre=togle_' + nombre + '&authenticity_token=' + tk + '&utf8=✓', type: 'POST', success: function() { return false; }});
    }
  }
});
