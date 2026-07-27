// Converted from errors.js.coffee for Rails 7.2 compatibility
window.errors = {
  set: function() {
    var msgs = Array.prototype.slice.call(arguments);
    $('#errorExplanation').remove();

    msgs = _.flatten(msgs);
    if (msgs.length) {
      var div = $('<div class="errorExplanation" id="errorExplanation">');
      div.append($('<ul>'));
      for (var i = 0; i < msgs.length; i++) {
        div.find('ul').append($('<li>').html(msgs[i]));
      }
      var container;
      if ($('#form-modal:visible').length) {
        container = $('#form-modal .modal-body');
      } else {
        container = $('#flash-container');
      }
      container.prepend(div);
    }
  },

  any: function() {
    return $('#errorExplanation').length > 0;
  },

  none: function() {
    return !this.any();
  },

  clear: function() {
    errors.set([]);
  }
};
