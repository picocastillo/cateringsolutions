// Permite refrescar la pagina de tres formas:
// 1. Si no hay un #auto-refresh, simplemente hace un get a la url actual y reemplaza el #page con el resultado
// 2. Si hay un #auto-refresh (usar <% refresh ... %>), se puede configurar la url y la zona a updatear que puede ser un selector o el string especial js para delegar esa tarea al script que devuelva el server.
window.refreshPage = function(afterRefresh) {
  if ($('.modal.show').length > 0) return;
  var refresh = $('#auto-refresh');
  var updateList = refresh.data('update');
  var url = refresh.data('url') || location.href;
  var dataType = (updateList === 'js') ? 'script' : undefined;

  $.get(url, function(data) {
    if (updateList != null) {
      if (updateList !== 'js') {
        var elements = updateList.split(', ');
        for (var i = 0; i < elements.length; i++) {
          $(elements[i]).html($(data).find(elements[i] + " >"));
        }
      }
    } else {
      $('#page').html($(data).find('#page >'));
    }
    if (_.isFunction(afterRefresh)) { afterRefresh(); }
  }, dataType);
};

window.autoRefreshPage = function(afterRefresh) {
  if (!$('#auto-refresh').length) { return; }
  if ($('.modal.show').length > 0) return;
  var refresh = $('#auto-refresh');
  var updateList = refresh.data('update');
  var url = refresh.data('url') || location.href;
  var dataType = (updateList === 'js') ? 'script' : undefined;

  $.get(url, function(data) {
    if (updateList != null) {
      if (updateList !== 'js') {
        var elements = updateList.split(', ');
        for (var i = 0; i < elements.length; i++) {
          $(elements[i]).html($(data).find(elements[i] + " >"));
        }
      }
    } else {
      $('#page').html($(data).find('#page >'));
    }
    if (_.isFunction(afterRefresh)) { afterRefresh(); }
  }, dataType);
};

window.refreshPageInicio = function() {
  if (!$('#auto-refresh-inicio').length) { return; }
  $('#q_fecha').change();
};

window.refrescarCalendario = function() {
  if (!$('#calendar').length) { return; }
  $('#calendar').fullCalendar('refetchEvents');
};

// Es necesario limpiar el interval para casos en los que se refresca toda la #page, xq se reemplaza el #auto-refresh y x lo tanto vuelve a ejecutarse esto
clearInterval(window.interval);
App.onMount('#auto-refresh', function() {
  clearInterval(window.interval);
  if ($('#auto-refresh').length) {
    window.interval = setInterval(autoRefreshPage, $('#auto-refresh').data('every') * 1000);
  }
});

clearInterval(window.interval1);
App.onMount('#auto-refresh-inicio', function() {
  clearInterval(window.interval1);
  if ($('#auto-refresh-inicio').length) {
    window.interval1 = setInterval(refreshPageInicio, 60 * 10 * 1000);
  }
});

clearInterval(window.interval2);
App.onMount('#calendar', function() {
  clearInterval(window.interval2);
  if ($('#calendar').length) {
    window.interval2 = setInterval(refrescarCalendario, 60000);
  }
});
