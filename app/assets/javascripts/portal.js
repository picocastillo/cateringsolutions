App.onMount('body', function() {
  this.shortcuts({
    'F6': function() {
      if ($('#s2id_buscador_precios_global').hasClass('select2-dropdown-open')) {
        $('#s2id_buscador_precios_global').select2('close');
      } else {
        $('#s2id_buscador_precios_global').select2('open');
      }
    }
  });

  this.on('click', '.card.filtros .bg-info', function() {
    $(this).parent().find('[data-action="collapse"] i').toggleClass("ti-minus ti-plus");
    $(this).parent().find('.card-body').collapse("toggle");
    return false;
  });
});
