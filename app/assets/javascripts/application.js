//= require jquery-ui-dist/external/jquery/jquery.js
//= require jquery-ui-dist/jquery-ui.js
//= require moment/moment.js
//= require moment/locale/es.js
//= require rails-ujs
//= require popper
//= require bootstrap
//= require bootstrap-select
//= require onmount
//= require app.js.erb
//= require swiper/swiper-bundle.min
//= require turbolinks
//= require nprogress
//= require nprogress-turbolinks
//= require cable
//= require wordcloud/src/wordcloud2.js
//= require_tree ../../../vendor/assets/javascripts_client/
//= require_directory ../../../lib/assets/javascripts_client/
//= require_tree ./pedidos/
//= require daily_orders
//= require procesos
//= require jquery-ui/ui/effects/effect-highlight
//= require forms.js
//= require pannels.js
//= require errors.js
//= require motion.min.js
//= require toast.js
//= require underscore/underscore-min.js
//= require portal.js
//= require surveys.js

NProgress.configure({
  showSpinner: false,
});

App.onMount('.singledate', function() {
  $('.singledate').datepicker({
                    todayHighlight: true,
                    orientation: "bottom",
                    autoclose: true,
                    disableTouchKeyboard: mobile(),
                    clearBtn: true
  });
});

$.blockUI.defaults.message = null
$.blockUI.defaults.overlayCSS.backgroundColor = 'rgba(255, 255, 255, 1)'
$.blockUI.defaults.baseZ = 999
$.blockUI.defaults.css.padding = '5px'
$.blockUI.defaults.css.border = '3px solid #e9e9e9'
$.blockUI.defaults.css.color = '#fff'
$.blockUI.defaults.css.backgroundColor = '#999'
$.blockUI.defaults.fadeIn = 0
$.blockUI.defaults.fadeOut = 0

function mobile(){
  var mobile = false;
  if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|mini|windows\sce|palm/i.test(navigator.userAgent)) {
    mobile = true;
  }
  return mobile;
}

App.init();

App.onMount('.selectpicker', function() {
  $('.selectpicker').selectpicker({noneSelectedText: '- Seleccionar -'});
});

$(document).on("turbolinks:load",function(){
  $("input[name='authenticity_token']").val($("meta[name='csrf-token']").attr("content"));
  $('#tronco-menu').removeClass('hidden');
  
  // Initialize Bootstrap 4 tabs explicitly for Turbolinks compatibility
  $('a[data-toggle="tab"]').off('click.bs.tab.data-api').on('click', function(e) {
    e.preventDefault();
    var $this = $(this);
    var target = $this.attr('href');
    
    // Remove active from all tabs and panes
    $this.closest('.nav-tabs').find('.nav-link').removeClass('active');
    var $tabContent = $this.closest('.nav-tabs').siblings('.tab-content').first();
    if (!$tabContent.length) {
      $tabContent = $this.closest('.card, .row').find('.tab-content').first();
    }
    $tabContent.find('.tab-pane').removeClass('active show');
    
    // Add active to clicked tab and target pane
    $this.addClass('active');
    $(target).addClass('active show');
  });
})

function syncSidebarIcon() {
  // Sidebar is "closed/collapsed" when body has mini-sidebar (desktop) or no show-sidebar (mobile)
  var isClosed = $("body").hasClass("mini-sidebar") || $("body").hasClass("no-sidebar");
  var isMobile = (window.innerWidth || screen.width) < 768;

  if (isMobile) {
    // On mobile, sidebar is open only when show-sidebar is present
    var mobileOpen = $("body").hasClass("show-sidebar");
    $('.nav-toggler i').toggleClass('mdi-menu', !mobileOpen).toggleClass('mdi-close', mobileOpen);
    $('.nav-toggler-chica i').toggleClass('ti-menu', !mobileOpen).toggleClass('ti-close', mobileOpen);
  } else {
    // On desktop, sidebar is collapsed when mini-sidebar is present
    $('.nav-toggler-chica i').toggleClass('ti-menu', isClosed).toggleClass('ti-close', !isClosed);
    $('.nav-toggler i').toggleClass('mdi-menu', isClosed).toggleClass('mdi-close', !isClosed);
  }
}

function retocarMenu() {
  x = window.innerWidth > 0 ? window.innerWidth : this.screen.width;
  e = 70;
  $("body").removeClass("no-sidebar").addClass("mini-sidebar");
  syncSidebarIcon();
  var o = (window.innerHeight > 0 ? window.innerHeight : this.screen.height) - 1;
  o -= e, 1 > o && (o = 1), o > e && $(".page-wrapper").css("min-height", o + "px");
  $(".navbar-brand").show();
};
retocarMenu();

App.onMount('#main-wrapper', function() {
  retocarMenu();
  "use strict";
  jQuery(document).on("click", ".mega-dropdown", function (i) {
    i.stopPropagation()
  });
  $(".sidebartoggler").on("click", function () {
    $("body").hasClass("mini-sidebar") ? ($(".scroll-sidebar, .slimScrollDiv").css("overflow", "hidden").parent().css("overflow", "visible"), $("body").removeClass("mini-sidebar"),$(".navbar-brand span").show()) : ($(".scroll-sidebar, .slimScrollDiv").css("overflow-x", "visible").parent().css("overflow", "visible"), $("body").addClass("mini-sidebar"), $(".navbar-brand span").hide());
    syncSidebarIcon();
  });
  $(".nav-toggler").click(function () {
    $("body").toggleClass("show-sidebar");
    syncSidebarIcon();
  });
  // Close sidebar when clicking the backdrop on mobile
  $("#sidebar-backdrop").on("click", function() {
    $("body").removeClass("show-sidebar");
    syncSidebarIcon();
  });
  $(".search-box a, .search-box .app-search .srh-btn").on("click", function () {
    $(".app-search").toggle(200)
  });
  $(".right-side-toggle").click(function () {
    $(".right-sidebar").slideDown(50), $(".right-sidebar").toggleClass("shw-rside")
  });
  $('[data-toggle="tooltip"]').tooltip({ container: 'body' });
  $('[data-toggle="popover"]').popover();
  $("#sidebarnav").metisMenu();
  $(".scroll-sidebar").slimScroll({
    position: "left",
    size: "0px",
    height: "100%",
    allowPageScroll: false,
    railDraggable : true,
    wheelStep : 10,
    touchScrollStep : 75
  });
  // Fix fly-out menus: slimScroll sets inline overflow:hidden which clips fly-out submenus in mini mode
  if ($("body").hasClass("mini-sidebar") || $("body").hasClass("no-sidebar")) {
    $(".scroll-sidebar, .slimScrollDiv").css("overflow", "visible");
  }
  $(".message-center").slimScroll({
    position: "right",
    size: "5px",
    allowPageScroll: false,
    wheelStep : 10,
    touchScrollStep : 75
  });

  $(".list-task li label").click(function () {
    $(this).toggleClass("task-done")
  });
  $("#to-recover").on("click", function () {
    $("#loginform").slideUp(), $("#recoverform").fadeIn()
  });
  $('a[data-action="expand"]').on("click", function (i) {
    i.preventDefault(), $(this).closest(".card").find('[data-action="expand"] i').toggleClass("mdi-arrow-expand mdi-arrow-collapse"), $(this).closest(".card").toggleClass("card-fullscreen")
  });
  $('a[data-action="close"]').on("click", function () {
    $(this).closest(".card").removeClass().slideUp("fast")
  });
  if ('serviceWorker' in navigator && 'PushManager' in window) {
    navigator.serviceWorker.register('/cs_of_ws.js', { scope: '/' })
    .then(function(swReg) {
      swRegistration = swReg;
    })
    .catch(function(error) {
      console.log('Service Worker Error');
    });
  }
});

$.fn.selectpicker.Constructor.BootstrapVersion = '4';

$.fn.select2.defaults.resultText = function(item) {
  return item.text || alert('Defina el data-label en este select2');
};

$.fn.select2.defaults.openOnEnter = false;

$.fn.select2.defaults.allowClear = true;

var accentFold, asignarIdSegunValueMethod, filterPluginOpts, formatearResult, labelFor, markMatchInOptionData, optionDataToString;

accentFold = (function(_this) {
  return function(str) {
    return window.Select2.util.stripDiacritics(str).toUpperCase();
  };
})(this);
asignarIdSegunValueMethod = function(items, valueMethod) {
  var i, item, len;
  if (!valueMethod) {
    return items;
  }
  for (i = 0, len = items.length; i < len; i++) {
    item = items[i];
    item.id = item[valueMethod];
  }
  return items;
};

labelFor = function(item, options) {
  return item[options.label] || item.text || item.nombre;
};

formatearResult = function(item, query, options) {
  var template;
  if (options.template) {
    template = _.template(options.template);
    return template(item);
  } else {
    return labelFor(item, options) || alert("Defina el data-label para el resultText en este select2: " + ($(this).attr('id')));
  }
};

filterPluginOpts = function(options) {
  return _.pick(options, 'template', 'placeholder', 'dropdownCssClass', 'multiple', 'minimumInputLength', 'formatInputTooShort');
};

$.fn.remoteSelect2 = function(options) {
  return this.each(function() {
    var defaults;
    defaults = {
      minimumInputLength: 2,
      createSearchChoice: options.createIfNotFound ? function(term, data) {
        if (!data.some(function(item) {
          return accentFold(labelFor(item, options)) === accentFold(term);
        })) {
          return {
            id: term,
            text: term + " (nuevo)",
            selection: term
          };
        }
      } : void 0,
      ajax: {
        url: options.url,
        dataType: 'json',
        quietMillis: 250,
        data: function(term) {
          var baseParams, key, ref, selector;
          baseParams = {
            q: term
          };
          ref = $(this).data('params');
          for (key in ref) {
            selector = ref[key];
            baseParams[key] = $(selector).val();
          }
          return baseParams;
        },
        results: function(data) {
          return {
            results: asignarIdSegunValueMethod(data, options.valueMethod)
          };
        }
      },
      initSelection: function(select, callback) {
        var pre = select.data('pre');
        if (pre && pre.id !== null && pre.id !== undefined) {
          return callback(pre);
        }
      },
      formatResult: function(item, _, query) {
        return formatearResult(item, query, options);
      },
      formatSelection: function(item) {
        return item.selection || item[options.selection] || labelFor(item, options) || alert("Defina el data-label para el formatSelection en este select2: " + ($(this).attr('id')));
      }
    };
    return $(this).select2(_.defaults(filterPluginOpts(options), defaults));
  });
};

optionDataToString = function(option) {
  var key, ref, text, value;
  text = '';
  ref = option.data();
  for (key in ref) {
    value = ref[key];
    text += value.toString();
  }
  return text;
};

markMatchInOptionData = function(option, term) {
  var key, markedData, markup, ref, value;
  markedData = {};
  ref = option.data();
  for (key in ref) {
    value = ref[key];
    markup = [];
    window.Select2.util.markMatch(value.toString(), term, markup, _.identity);
    markedData[key] = markup.join('');
  }
  return markedData;
};

(function ($) {
    "use strict";

    $.extend($.fn.select2.defaults, {
        formatNoMatches: function () { return "No hay resultados"; },
        formatInputTooShort: function (input, min) { var n = min - input.length; return "Introduzca al menos " + n + " car" + (n == 1? "ácter" : "acteres"); },
        formatInputTooLong: function (input, max) { var n = input.length - max; return "Elimine " + n + " car" + (n == 1? "ácter" : "acteres"); },
        formatSelectionTooBig: function (limit) { return "Sólo puede seleccionar " + limit + " elemento" + (limit == 1 ? "" : "s"); },
        formatLoadMore: function (pageNumber) { return "Cargando resultados…"; },
        formatSearching: function () { return "Buscando…"; }
    });
})(jQuery);

App.onMount('select.select2-local', function() {
  var opts, template;
  opts = this.data();
  if (this.data('template')) {
    template = _.template(this.data('template'));
    opts = _.merge(opts, {
      formatResult: function(item, _, query) {
        return template(markMatchInOptionData($(item.element), query.term));
      },
      matcher: function(term, _, option) {
        return accentFold(optionDataToString(option)).indexOf(accentFold(term)) >= 0;
      },
      escapeMarkup: function(m) {
        return m;
      }
    });
  }
  return this.select2(opts);
});

App.onMount('input.select2-remote', function() {
    this.remoteSelect2(this.data());
    // Explicitly set pre-selection in case initSelection didn't render the display.
    // select2 v3 sometimes skips rendering when the element is hidden or not yet
    // fully in the layout at mount time.
    var pre = this.data('pre');
    if (pre && pre.id !== null && pre.id !== undefined) {
      this.select2('data', pre);
    }
});
