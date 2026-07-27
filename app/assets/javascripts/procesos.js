App.onMount('#resultados-procesos', function() {
  console.log("Procesos onMount fired, App.cable:", !!App.cable, "App.procesos:", !!App.procesos);
  if (typeof App === 'undefined' || !App.cable) return;
  if (App.procesos) return; // Already subscribed

  App.procesos = App.cable.subscriptions.create("ProcesosChannel", {
    connected: function() {
      console.log("Connected to Procesos channel");
    },

    disconnected: function() {
      console.log("Disconnected from Procesos channel");
    },

    received: function(data) {
      console.log("Procesos received:", data);
      if (data.type === 'procesos_update') {
        refreshPage();
      }
    }
  });
});
