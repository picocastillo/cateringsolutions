App.onMount('.drag-and-drop-documentos-section', function() {
  var section = this;

  this.fileupload({
    url: '/documentos?authenticity_token=' + encodeURIComponent($('meta[name="csrf-token"]').attr("content")) + '&utf8=✓',
    sequentialUploads: true,
    dataType: 'script',
    formData: function(form) {
      // Por defecto submitea todo el form y si estoy editando un documentable mandaria un method patch en lugar del post
      return form.find(':input:not([name=_method])').serializeArray();
    },
    start: function() {
      $('.loading-indicator').fadeIn('fast');
    },
    stop: function() {
      $('.loading-indicator').hide();
    },
    add: function(_, data) {
      var file = data.files[0];
      var maxSize = parseFloat($(this).data('max-size'));
      if (maxSize > 0 && file.size > maxSize * 1000 * 1024) {
        errors.set("El archivo '" + file.name + "' no puede ser superior a " + maxSize + " MB.");
      } else {
        if ($(this).data('solo-imagenes')) {
          var types = /(\.|\/)(jpe?g|png|gif)$/i;
          if (types.test(file.type) || types.test(file.name)) {
            data.submit();
          } else {
            errors.set("El archivo '" + file.name + "' no es una imagen jpg, png o gif.");
          }
        } else {
          data.submit();
        }
      }
    }
  });

  this.on('click', '.upload-link', function(e) {
    $('.upload-input', section).click();
    e.preventDefault();
  });

  this.on('click', '.quitar-archivo', function() {
    $(this).closest('li').fadeOut('fast', function() { $(this).remove(); });
  });
});
