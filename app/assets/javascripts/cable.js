// Action Cable provides the framework to deal with WebSockets in Rails.
// You can generate new channels where WebSocket features live using the `rails generate channel` command.
//
//= require action_cable
//= require_self

(function() {
  // Ensure App object exists
  if (typeof App === 'undefined') {
    window.App = {};
  }
  
  // Initialize Action Cable only if not already initialized
  if (!App.cable) {
    // Use the same protocol and port as the current page
    var cableUrl = window.location.protocol === 'https:' ? 'wss://' : 'ws://';
    cableUrl += window.location.host + '/cable';
    
    App.cable = ActionCable.createConsumer(cableUrl);
    console.log("Action Cable initialized with URL:", cableUrl);
  }
}).call(this);
