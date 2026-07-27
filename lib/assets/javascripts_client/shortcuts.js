$.fn.shortcuts = function(keysAndActions) {
  for (var keys in keysAndActions) {
    if (keysAndActions.hasOwnProperty(keys)) {
      $(this).shortcut(keys, keysAndActions[keys]);
    }
  }
};

$.fn.shortcut = function(keys, action) {
  return this.each(function() {
    shortcut.remove(keys);
    shortcut.add(keys, action, {target: this});
  });
};

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
