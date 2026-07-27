function removeExtraTips() {
  var qtips = $('#growl-container .qtip');
  var removeQty = /Android|webOS|iPhone|iPad|iPod|BlackBerry|mini|windows\sce|palm/i.test(navigator.userAgent) ? 2 : 1;
  qtips.slice(0, removeQty).remove();
}

window.growl = function(message, options) {
  options = options || {};
  if (!message) return;

  var defaults = {lifespan: 5000, closeButton: false, title: null, style: null, onClick: null};
  options = $.extend(defaults, options);

  var additionalClasses = [];
  if (options.style) additionalClasses.push('qtip-' + options.style);
  if (options.onClick) additionalClasses.push('clickable');

  removeExtraTips();

  $("<div />").qtip({
    content: {
      text: message,
      title: {
        text: options.title,
        button: options.closeButton
      }
    },
    position: {
      target: [0, 0],
      container: $("#growl-container")
    },
    show: {
      event: false,
      ready: true,
      effect: function() { $(this).stop(0, 1).show(); },
      delay: 0,
      persistent: options.lifespan === 0
    },
    hide: {
      event: false,
      effect: function(api) { 
        $(this).stop(0, 1).fadeOut(function() { 
          $(this).remove(); 
        }); 
      }
    },
    style: {
      width: options.width,
      classes: ['alert'].concat(additionalClasses).join(' '),
      tip: false
    },
    events: {
      render: function(event, api) {
        if (!api.options.show.persistent) {
          $(this).bind("mouseover mouseout", function(e) {
            clearTimeout(api.timer);
            if (e.type !== "mouseover") {
              api.timer = setTimeout(function() { api.hide(e); }, options.lifespan);
            }
          }).triggerHandler("mouseout");
        }

        if (options.onClick) {
          $(event.target).one('click', options.onClick);
        }
      }
    }
  });
};