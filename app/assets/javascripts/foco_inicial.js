$.fn.press = function() {
  return this.each(function() {
    var btn = $(this);
    if (btn.hasClass('btn')) {
      $(this).addClass('active').click();
      setTimeout(function() { btn.removeClass('active'); }, 50);
    } else {
      btn.effect("highlight");
      btn[0].click();
    }
  });
};

$.fn.focoInicial = function() {
  return this.each(function() {
    if (!mobile()) {
      var container = $(this);
      if (container.find('.focus:visible').last().focus().select().length === 0) {
        var firstInputSelector = ":input:visible:enabled:first";
        if (container.find(".error " + firstInputSelector).focus().select().length === 0) {
          if (container.is('body')) {
            container = container.find('form:not(.navbar-search):first');
          }
          container.find(firstInputSelector).focus().select();
        }
      }
    }
  });
};

// Si en alguna pagina se desea controlar el focus manualmente, agregar un data-manualfocus
// El setTimeout es necesario xq sino los select2 no toman foco
App.onMount('body:not(:has([data-manualfocus]))', function() {
  var self = this;
  setTimeout(function() { self.focoInicial(); }, 0);
});

$(document).on('click', '.kiosk_pagination.ajax a', function() {
  var href = this.href;
  history.pushState({requestPage: true, turbolinks: true}, null, $.param.querystring(location.pathname, href));
  $.getScript(href);
  return false;
});

$(document).on('click', 'table #toggle-all', function() {
  $(this).closest('table').find('tbody input[type=checkbox]').prop('checked', $(this).is(':checked'));
});
