//= require activestorage
//= require chart.js/dist/chart.umd
//= require jquery_nested_form
//= require jquery-fileupload/basic
//= require jquery-ui/ui/widgets/draggable
//= require_tree ../../../vendor/assets/javascripts/
//= require_directory ../../../lib/assets/javascripts/extensions
//= require_directory ../../../lib/assets/javascripts
//= require cable.js


//= require refresh.js

//= require foco_inicial.js

//= require_tree ./usuarios/
//= require_tree ./ventas_mostrador/
//= require_tree ./cobros/
//= require_tree ./infraestructura/

App.onMount('.daterange', function() {
  $('.daterange').daterangepicker({autoApply: true,
    "locale": {
          "format": "DD/MM/YYYY",
          "separator": " - ",
          "applyLabel": "Aceptar",
          "cancelLabel": "Cancelar",
          "fromLabel": "Desde",
          "toLabel": "Hasta",
          "customRangeLabel": "Personalizado",
          "weekLabel": "S",
          "daysOfWeek": [
              "Do",
              "Lu",
              "Ma",
              "Mi",
              "Ju",
              "Vi",
              "Sa"
          ],
          "monthNames": [
              "Enero",
              "Febrero",
              "Marzo",
              "Abril",
              "Mayo",
              "Junio",
              "Julio",
              "Augosto",
              "Septiembre",
              "Octubre",
              "Noviembre",
              "Deciembre"
          ],
          "firstDay": 1
      }
    });
});



App.onMount('.singleclock', function() {
  $('.singleclock').clockpicker({
      placement: 'bottom',
      align: 'left',
      autoclose: true,
      'default': 'now'
  });
});

App.onMount('#index-menus-diarios, .selectpicker-menu-diario', function() {
  $('.selectpicker-menu-diario').selectpicker({dropupAuto:true, liveSearchPlaceholder: 'Seleccione o busque productos de menús diarios', liveSearch: true, liveSearchNormalize: true, noneSelectedText: '- Todos los Productos -', actionsBox: true, deselectAllText: 'Todos', noneResultsText: '<div style="padding: 5px 10px;margin: 5px">No se encontraron productos de menú diario con nombre {0}.</div>', selectedTextFormat: 'count > 6', countSelectedText: '{0} Productos Seleccionados', showSubtext: true, virtualScroll: true, mobile: mobile()});
});

App.onMount('.categoria-chips-wrap', function() {
  var $wrap = $(this);
  var $select = $wrap.find('select.categoria-select-hidden');
  if (!$select.length) return;

  function syncChipsFromSelect() {
    var selected = {};
    $select.find('option:selected').each(function() { selected[$(this).val()] = true; });
    $wrap.find('.categoria-chip[data-categoria-id]').each(function() {
      var $chip = $(this);
      var on = !!selected[String($chip.data('categoria-id'))];
      $chip.toggleClass('is-selected', on).attr('aria-pressed', on);
    });
  }

  $wrap.off('click.chips').on('click.chips', '.categoria-chip[data-categoria-id]', function(e) {
    e.preventDefault();
    var id = String($(this).data('categoria-id'));
    var $opt = $select.find('option').filter(function() { return $(this).val() === id; });
    $opt.prop('selected', !$opt.prop('selected'));
    syncChipsFromSelect();
    $select.trigger('change');
  });

  $wrap.on('click.chips', '.categoria-chip[data-chip-action]', function(e) {
    e.preventDefault();
    var action = $(this).data('chip-action');
    $select.find('option').prop('selected', action === 'all');
    syncChipsFromSelect();
    $select.trigger('change');
  });

  syncChipsFromSelect();
});

App.onMount('.selectpicker-categorias', function() {
  $('.selectpicker-categorias').selectpicker({dropupAuto:true, noneSelectedText: '- Todas Activas -', countSelectedText: '{0} Productos Seleccionados', showSubtext: true, virtualScroll: true, selectedTextFormat: 'count > 6', countSelectedText: '{0} Categorías Seleccionados', actionsBox: true, deselectAllText: 'Todas', selectAllText: false, mobile: mobile()});
});

App.onMount('.selectpicker-tiendas', function() {
  $('.selectpicker-tiendas').selectpicker({dropupAuto:true, noneSelectedText: '- Ninguna -', countSelectedText: '{0} Tiendas Seleccionadas', showSubtext: true, virtualScroll: true, selectedTextFormat: 'count > 6', countSelectedText: '{0} Tiendas Seleccionadas', actionsBox: true, deselectAllText: 'Ninguna', selectAllText: false, mobile: mobile()});
});

App.onMount('.selectpicker-locales', function() {
  $('.selectpicker-locales').selectpicker({dropupAuto:true, noneSelectedText: '- Ninguna -', countSelectedText: '{0} Locales Seleccionados', showSubtext: true, virtualScroll: true, selectedTextFormat: 'count > 6', actionsBox: true, deselectAllText: 'Ninguno', selectAllText: false, mobile: mobile()});
});

App.onMount('#edit-producto .selectpicker-precios-clientes, #new-producto .selectpicker-precios-clientes', function() {
  $('.selectpicker-precios-clientes').selectpicker({dropupAuto:true, noneSelectedText: '- Todos -', showSubtext: true, virtualScroll: true, actionsBox: true, deselectAllText: 'Todos', mobile: mobile()});
});

App.onMount('#edit-usuario .selectpicker-cuentas-usuario, #new-usuario .selectpicker-cuentas-usuario', function() {
  $('.selectpicker-cuentas-usuario').selectpicker({dropupAuto:true, noneSelectedText: '- Ninguno -', showSubtext: true, virtualScroll: true, actionsBox: true, mobile: mobile()});
});

App.onMount('#form-modal .singledate', function() {
  $('.singledate').datepicker({todayHighlight: true,autoclose: true, orientation: "auto", disableTouchKeyboard: mobile(),
  clearBtn: true});
});

// Legacy bootstrap-select for `.selectpicker-new-menu` is no longer used by
// the MenuDiario form (replaced by the search-and-add picker below). Kept as
// a no-op fallback in case other modals still ship that class — the global
// `App.onMount('#form-modal .selectpicker', …)` already handles them.

// ─── MenuDiario producto picker ──────────────────────────────────────────────
// A search-driven, chip-based picker that mirrors the Venta Mostrador
// product-search UX but for HABTM `producto_ids`. All filtering happens
// client-side against tipo-specific JSON datasets pre-rendered on the wrapper,
// so it stays snappy and survives modal injection (idempotent via App.onMount).
App.onMount('#menu-diario-productos-wrapper', function() {
  var $wrapper      = $(this);
  var $tipo         = $('#menu-diario-tipo-select');
  var $desc         = $('#menu_diario_descripcion');
  var $search       = $wrapper.find('#md-picker-search');
  var $searchBar    = $search.closest('.md-picker__searchbar');
  var $clear        = $wrapper.find('#md-picker-clear');
  var $results      = $wrapper.find('#md-picker-results');
  var $selected     = $wrapper.find('#md-picker-selected');
  var $selectedCnt  = $wrapper.find('#md-picker-selected-count');
  var $count        = $wrapper.find('#md-picker-count');

  if (!$wrapper.length || !$search.length) return;

  var TIPO_MD = parseInt($wrapper.data('tipo-menu-diario'), 10);
  var TIPO_PD = parseInt($wrapper.data('tipo-productos-diarios'), 10);
  var DEFAULT_DESC_PD = $wrapper.data('default-desc-pd') || '';
  var SOPORTA_PD = String($wrapper.data('soporta-productos-diarios')) === 'true';

  function parseList(attr) {
    var raw = $wrapper.attr('data-' + attr);
    if (!raw) return [];
    try { return JSON.parse(raw); } catch (e) { return []; }
  }
  var catalogMd  = parseList('md-productos');
  var catalogPd  = parseList('pd-productos');
  var initialSel = parseList('preselected');
  var initialDesc = ($desc.val() || '').trim();

  // Selected ids ordered by insertion. Map id -> producto payload for fast
  // lookups; chip rendering is driven from this map.
  var selectedById = {};
  var selectedOrder = [];
  initialSel.forEach(function(p) {
    selectedById[p.id] = p;
    selectedOrder.push(p.id);
  });

  function currentTipo() {
    if (!$tipo.length) return TIPO_MD;
    var v = parseInt($tipo.val(), 10);
    return isNaN(v) ? TIPO_MD : v;
  }
  function currentCatalog() {
    return currentTipo() === TIPO_PD ? catalogPd : catalogMd;
  }
  function syncWrapperTipoFlag() {
    $wrapper.attr('data-current-tipo', currentTipo() === TIPO_PD ? 'pd' : 'md');
  }

  // Normalize for accent-insensitive search.
  function normalize(s) {
    return (s || '').toString()
      .toLowerCase()
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  }

  function htmlEscape(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function renderResults() {
    var query = normalize($search.val());
    var catalog = currentCatalog();
    var matches = catalog;
    if (query.length) {
      matches = catalog.filter(function(p) {
        return normalize(p.label).indexOf(query) !== -1
            || normalize(p.codigo).indexOf(query) !== -1;
      });
    }
    var visible = matches.slice(0, 30);

    if (!catalog.length) {
      $results.html('<div class="md-picker__results-empty">No hay productos disponibles para este tipo.</div>');
    } else if (!visible.length) {
      $results.html('<div class="md-picker__results-empty">Sin resultados para "' + htmlEscape($search.val()) + '"</div>');
    } else {
      var html = visible.map(function(p) {
        var disabled = selectedById.hasOwnProperty(p.id);
        return '' +
          '<div class="md-picker__row' + (disabled ? ' is-disabled' : '') + '" ' +
                'role="option" data-id="' + p.id + '">' +
            '<span class="md-picker__swatch" style="background:' + htmlEscape(p.color) + '"></span>' +
            '<div class="md-picker__row-body">' +
              '<div class="md-picker__row-title">' +
                (p.codigo ? '<span class="md-picker__codigo">' + htmlEscape(p.codigo) + '</span>' : '') +
                htmlEscape(p.nombre || p.label) +
              '</div>' +
              (p.categoria ? '<div class="md-picker__row-cat">' + htmlEscape(p.categoria) + '</div>' : '') +
            '</div>' +
            '<button type="button" class="md-picker__row-add" title="Agregar" ' +
                    (disabled ? 'disabled' : '') + ' aria-label="Agregar ' + htmlEscape(p.nombre || p.label) + '">+</button>' +
          '</div>';
      }).join('');
      $results.html(html);
    }

    $count.text(catalog.length ? ('de ' + catalog.length + ' productos') : '');
  }

  function renderSelected() {
    if (!selectedOrder.length) {
      $selected.empty();
    } else {
      var html = selectedOrder.map(function(id) {
        var p = selectedById[id];
        if (!p) return '';
        return '' +
          '<div class="md-picker__chip" data-id="' + id + '" ' +
               'style="--md-chip-color:' + htmlEscape(p.color) + '">' +
            (p.codigo ? '<span class="md-picker__chip-codigo">' + htmlEscape(p.codigo) + '</span>' : '') +
            '<span class="md-picker__chip-name">' + htmlEscape(p.nombre || p.label) + '</span>' +
            '<button type="button" class="md-picker__chip-remove" aria-label="Quitar">×</button>' +
            '<input type="hidden" name="menu_diario[producto_ids][]" value="' + id + '">' +
          '</div>';
      }).join('');
      $selected.html(html);
    }
    $selectedCnt.text(selectedOrder.length);
  }

  function add(id) {
    var p = currentCatalog().find(function(x) { return x.id === id; })
         || initialSel.find(function(x) { return x.id === id; });
    if (!p || selectedById[id]) return;
    selectedById[id] = p;
    selectedOrder.push(id);
    renderSelected();
    renderResults();
    $search.focus();
  }

  function remove(id) {
    if (!selectedById[id]) return;
    delete selectedById[id];
    selectedOrder = selectedOrder.filter(function(x) { return x !== id; });
    renderSelected();
    renderResults();
  }

  function onTipoChange() {
    // Drop selections that don't belong to the new tipo's catalog so the
    // server-side `productos_acordes_al_tipo` validator never sees mismatches.
    var validIds = {};
    currentCatalog().forEach(function(p) { validIds[p.id] = true; });
    selectedOrder = selectedOrder.filter(function(id) {
      if (validIds[id]) return true;
      delete selectedById[id];
      return false;
    });

    syncWrapperTipoFlag();
    renderSelected();
    $search.val('');
    $searchBar.removeClass('is-filled');
    renderResults();
    syncPdHint();

    // Default descripción for "Productos del Día" when blank or unchanged.
    if ($desc.length && SOPORTA_PD && currentTipo() === TIPO_PD) {
      var current = ($desc.val() || '').trim();
      if (current === '' || current === initialDesc) {
        $desc.val(DEFAULT_DESC_PD).trigger('change');
      }
    }
  }

  function syncPdHint() {
    var $hint = $('#menu-diario-pd-hint');
    if (!$hint.length) return;
    $hint.toggle(currentTipo() === TIPO_PD);
  }

  // ── wire events (namespaced so re-mounts don't pile up handlers) ──
  $search.off('input.mdPicker').on('input.mdPicker', function() {
    $searchBar.toggleClass('is-filled', !!this.value.length);
    renderResults();
  });
  $search.off('keydown.mdPicker').on('keydown.mdPicker', function(e) {
    if (e.key === 'Escape') {
      $search.val(''); $searchBar.removeClass('is-filled'); renderResults();
    } else if (e.key === 'Enter') {
      e.preventDefault();
      var $first = $results.find('.md-picker__row:not(.is-disabled)').first();
      if ($first.length) add(parseInt($first.data('id'), 10));
    }
  });
  $clear.off('click.mdPicker').on('click.mdPicker', function() {
    $search.val(''); $searchBar.removeClass('is-filled'); renderResults(); $search.focus();
  });
  $results.off('click.mdPicker').on('click.mdPicker', '.md-picker__row:not(.is-disabled)', function() {
    add(parseInt($(this).data('id'), 10));
  });
  $selected.off('click.mdPicker').on('click.mdPicker', '.md-picker__chip-remove', function() {
    var $chip = $(this).closest('.md-picker__chip');
    remove(parseInt($chip.data('id'), 10));
  });
  if ($tipo.length) {
    $tipo.off('change.mdPicker').on('change.mdPicker', onTipoChange);
  }

  // ── refetch PD catalog when fecha changes ──
  // The PD catalog must hide productos already used by another
  // productos_diarios menu on the same date. Server renders an initial filter
  // based on @menu_diario.fecha, but when the user opens "Nuevo" without a
  // fecha or changes it inside the modal, we re-fetch the available list.
  var $fecha = $wrapper.closest('form').find('input.singledate, #menu_diario_fecha').first();
  if ($fecha.length) {
    var refetchTimer = null;
    var refetchPdCatalog = function() {
      var fecha = ($fecha.val() || '').trim();
      if (!fecha) return;
      var data = { fecha: fecha };
      var excludeId = parseInt($wrapper.data('menu-diario-id'), 10);
      if (!isNaN(excludeId) && excludeId > 0) data.exclude_id = excludeId;
      $.getJSON('/menus_diarios/productos_disponibles', data, function(resp) {
        if (!resp) return;
        if (Array.isArray(resp.pd)) catalogPd = resp.pd;
        if (Array.isArray(resp.md)) catalogMd = resp.md;
        // Drop any selected productos that are no longer available.
        var validIds = {};
        currentCatalog().forEach(function(p) { validIds[p.id] = true; });
        selectedOrder = selectedOrder.filter(function(id) {
          if (validIds[id] || !SOPORTA_PD) return true;
          delete selectedById[id];
          return false;
        });
        renderSelected();
        renderResults();
      });
    };
    $fecha.off('change.mdPicker').on('change.mdPicker', function() {
      clearTimeout(refetchTimer);
      refetchTimer = setTimeout(refetchPdCatalog, 150);
    });
  }

  syncWrapperTipoFlag();
  renderSelected();
  renderResults();
  syncPdHint();
});

App.onMount('#index-menus-diarios', function() {

  "use strict";

    var CalendarApp = function() {
        this.$body = $("body")
        this.$calendar = $('#calendar'),
        this.$event = ('#calendar-events div.calendar-events'),
        this.$modal = $('#form-modal'),
        this.$calendarObj = null
    };


    /* on click on event */
    CalendarApp.prototype.onEventClick =  function (calEvent, jsEvent, view) {
        $.get("/menus_diarios/"+calEvent.id+"/edit")
    },
    /* on select */
    CalendarApp.prototype.onSelect = function (start, end, allDay) {
      $.get("/menus_diarios/new", {fecha: moment(start).format('DD-MM-Y')})
    }
    /* Initializing */
    CalendarApp.prototype.init = function() {
        var date = new Date();
        var d = date.getDate();
        var m = date.getMonth();
        var y = date.getFullYear();
        var form = '';
        var today = new Date($.now());
        var m_ids = $('#producto-menu-diario').val();
        var $this = this;
        $this.$calendarObj = $this.$calendar.fullCalendar({
            allDayDefault: true,
            height: 450,
            minTime: '04:00:00',
            maxTime: '08:00:00',
            durationEditable: false,
            defaultView: 'laborweek',
            handleWindowResize: true,
            disableResizing: true,
            allDaySlot: true,
            views: {
                laborweek: {
                    type: 'agendaWeek',
                    duration: {
                      week: 1
                    },
                    title: 'Semana'
                },
                labormonth: {
                    type: 'month',
                    duration: {
                      month: 1
                    },
                    title: 'Mes'
                },
                laborday: {
                    type: 'agendaDay',
                    duration: {
                      day: 1
                    },
                    title: 'Día'
                }
            },
            header: {
                right: 'prev,next',
                center: 'title',
                left: 'laborweek,labormonth,laborday'
            },
            events: {
              url: '/menus_diarios',
              type: 'GET',
              data: {
                producto_ids: function() {
                   return ($('#producto-menu-diario').val() || []).join(',')
                }
              },
              error: function() {
                console.log('Error obteniendo eventos!');
              },
                complete: function (data) {
                  if($('#input-highlight').val() > 0) {
                    var light = '.evento-cal-'+ $('#input-highlight').val();
                    $(light).parent().effect("highlight", {color:"#fff849"}, 6000);
                    $('#input-highlight').val(0)
                  }
              }
            },
            eventRender: function(event, element) {
              element.attr('title', event.tooltip);
            },
            editable: false,
            droppable: false, // this allows things to be dropped onto the calendar !!!
            eventLimit: false, // allow "more" link when too many events
            selectable: true,
            select: function (start, end, allDay) { $this.onSelect(start, end, allDay); },
            dayClick: function (date, jsEvent, view) { $this.onSelect(date, date, true); },
            eventClick: function(calEvent, jsEvent, view) { $this.onEventClick(calEvent, jsEvent, view); }
        });

    },

   //init CalendarApp
    $.CalendarApp = new CalendarApp, $.CalendarApp.Constructor = CalendarApp
    $.CalendarApp.init()
    $(document).off('change.mdCalRefetch changed.bs.select.mdCalRefetch', '#producto-menu-diario')
      .on('change.mdCalRefetch changed.bs.select.mdCalRefetch', '#producto-menu-diario', function() {
        if ($('#calendar').length) {
          $('#calendar').fullCalendar('refetchEvents');
        }
      });

    // Fallback: the all-day strip in agendaWeek/agendaDay sometimes ignores
    // single clicks (FullCalendar v3 only fires `select` after a drag in that
    // strip). Bind the new-menu action directly to those <td.fc-day> cells so
    // a single click anywhere in the strip opens the new modal for that date.
    $(document).on('click', '#calendar .fc-day-grid td.fc-day[data-date]', function (e) {
      // Don't intercept clicks on existing events.
      if ($(e.target).closest('.fc-event').length) return;
      var date = $(this).data('date');
      if (!date) return;
      $.get('/menus_diarios/new', { fecha: moment(date).format('DD-MM-Y') });
    });
})


function asyncProxy(fn, options, ctx) {
  var timer = null;
  var counter = 0;
  var _call = function (args) {
    counter = 0;

    fn.apply(ctx, args);
  };

  ctx = ctx || window;
  options = $.extend({
    delay: 0,
    stack: Infinity
  }, options);

  return function () {
    counter++;

    // prevent calling the delayed function multiple times
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }

    if (counter >= options.stack) {
      _call(arguments);
    } else {
      var args = arguments;

      timer = setTimeout(function () {
        timer = null;
        _call(args);
      }, options.delay);
    }
  };
}

var processWindowResize = asyncProxy(function (event) {
  // Only resize page-wrapper height, don't toggle sidebar
  var e = 70;
  var o = (window.innerHeight > 0 ? window.innerHeight : screen.height) - 1;
  o -= e;
  if (o < 1) o = 1;
  if (o > e) $(".page-wrapper").css("min-height", o + "px");
}, {
  delay: 500
});

$(window).on('resize', processWindowResize);
