$.fn.clearForm = function() {
  return this.each(function() {
    var el = $(this);
    if (el.hasClass('select2') && !el.data('dont-clear')) {
      el.select2('val', '');
    } else if (el.is('.subform, form')) {
      $(':input:not(.btn, [type=hidden]), .select', this).clearForm();
    } else if (this.type === 'text' || this.type === 'password' || el.is('textarea')) {
      this.value = el.data('default-value') || '';
    } else if (this.type === 'checkbox' || this.type === 'radio') {
      this.checked = false;
    } else if (el.is('select') && !el.data('dont-clear')) {
      this.selectedIndex = el.data('default-value') ? el.find("option[value='" + el.data('default-value') + "']").index() : 0;
      el.change();
    }
    return true;
  });
};

$.fn.serializeClosestForm = function(options) {
  var defaults = {
    exclude: '',
    include: '',
    asArray: false
  };
  options = $.extend(defaults, options);

  var inputs = $(this).closest('form,.mini-form').find('input,textarea,select')
    .filter(":not([name=_method])")
    .not($(options.exclude))
    .add($(options.include));

  if (options.asArray) {
    return inputs.serializeArray();
  } else {
    return inputs.serialize();
  }
};

$(document).on('keypress', '.subform :input', function(e) {
  if (e.which === 13 && !e.ctrlKey) {
    var subform = $(this).closest('.subform');
    if (!$('.blockUI.blockOverlay').length) {
      if (!$('.btn-primary', subform).press().length) {
        $('.btn:not(.dropdown-toggle,.add-on):first', subform).press();
      }
    }
    return false;
  }
});

$(document).on('keypress', 'textarea', function(e) {
  if (e.which === 13 && e.ctrlKey) {
    $(this).closest('form').submit();
    return false;
  }
});

$(document).on('click', '.clear-form', function() {
  $(this).closest('.subform, form').clearForm();
  return false;
});

App.onMount('#print_on_load_required', function() {
  var id = $('#print_on_load_required #print_on_load_id').data('a-imprimir');
  if (id) {
    $("#" + id).click();
  } else {
    $('a.print_on_load').click();
  }
  this.remove();
});

// Activate a tab from URL parameter: ?tab=Precios
// Highlight and scroll to a specific row: ?precio_id=123
$(document).on('turbolinks:load', function() {
  var params = new URLSearchParams(window.location.search);
  var tab = params.get('tab');
  if (tab) {
    var $tabLink = $('.nav-tabs a[data-toggle="tab"]').filter(function() {
      return $(this).text().trim() === tab;
    });
    if ($tabLink.length) { $tabLink.tab('show'); }
  }

  var precioId = params.get('precio_id');
  if (precioId) {
    var $row = $('tr[data-precio-id="' + precioId + '"]');
    if ($row.length) {
      // If the row is hidden (collapsed "anteriores"), expand all
      if (!$row.is(':visible')) {
        $('.precio-anterior').show();
        var $btn = $('#toggle-precios-anteriores');
        if ($btn.length) { $btn.html('<i class="fa fa-eye-slash"></i> Ocultar anteriores'); }
      }
      $row.css('background-color', '#fff3cd');
      setTimeout(function() {
        $row[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
      }, 300);
    }
  }
});