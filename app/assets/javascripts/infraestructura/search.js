App.onMount('#new_q', function() {
  this.on('submit', function() {
    $('.ajax-data-container').block();
    if ($(this).data('remote')) {
      App.url.updateWithParams($('#new_q').serializeClosestForm());
    }
  });
});
