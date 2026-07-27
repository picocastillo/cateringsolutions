App.onMount('#daily-orders-container, #inicio-link-notification', function() {

    console.log("🔄 Daily Orders script loaded");
    
    // Wait for Action Cable to be available
    function initializeDailyOrdersChannel() {
      if (typeof App !== 'undefined' && App.cable) {
        console.log("✅ Initializing Daily Orders channel...");
        console.log("📡 ActionCable URL:", App.cable.url);
        
        // Subscribe to daily orders updates
        App.dailyOrders = App.cable.subscriptions.create("DailyOrdersChannel", {
          connected: function() {
            console.log("🔗 Connected to Daily Orders channel");
          },
          
          disconnected: function() {
            console.log("❌ Disconnected from Daily Orders channel");
          },
          
          received: function(data) {
            console.log("📨 Received daily orders update:", data);
            
            // Update the daily orders partial with new data
            if (data.html) {
              const dailyOrdersContainer = document.querySelector('#daily-orders-container');
              if (dailyOrdersContainer) {
                dailyOrdersContainer.innerHTML = data.html;
                
                // Add smooth transition effect
                dailyOrdersContainer.style.opacity = '0.7';
                setTimeout(() => {
                  dailyOrdersContainer.style.opacity = '1';
                }, 200);
              }
            }
            
            // Update individual counters if provided
            if (data.counters) {
              this.updateCounters(data.counters);
            }
          },
          
          updateCounters: function(counters) {
            // Update individual counter elements with animation
            Object.keys(counters).forEach(key => {
              if (key === 'pedidos_pendientes_cortes') return; // handled below
              const element = document.querySelector(`[data-counter="${key}"]`);
              if (element) {
                const oldValue = parseInt(element.textContent);
                const newValue = counters[key];
              
                // Add pulse animation for changed values
                element.classList.add('counter-updated');
                element.textContent = newValue;
                
                setTimeout(() => {
                  element.classList.remove('counter-updated');
                }, 2000);
              }
            });

            // Update "Próximos cortes" section
            var cortesContainer = document.querySelector('[data-cortes]');
            if (cortesContainer && counters.pedidos_pendientes_cortes) {
              var cortes = counters.pedidos_pendientes_cortes.filter(function(v, i, a) { return v && a.indexOf(v) === i; }).sort();
              if (cortes.length > 0) {
                var now = new Date();
                var nowTime = ('0' + now.getHours()).slice(-2) + ':' + ('0' + now.getMinutes()).slice(-2);
                var nextCorte = cortes.find(function(c) { return c > nowTime; });
                var html = 'Próximos cortes:<br><strong>' +
                  cortes.map(function(x) {
                    if (x === nextCorte) {
                      return '<span class="badge badge-warning">' + x + 'hs</span>';
                    }
                    return x + 'hs';
                  }).join(' ') + '</strong>';
                cortesContainer.innerHTML = html;
              } else {
                cortesContainer.innerHTML = 'en espera';
              }
            }

            // Update notification style after counter updates
            if (typeof window.updateNotificationStyle === 'function') {
              window.updateNotificationStyle();
            }
            
            // Update inicio-link-notification style based on counters
            this.updateNotificationStyle(counters);
          },
          
          updateNotificationStyle: function(counters) {
            const notificationElement = document.getElementById('inicio-link-notification');
            const notificationElementIcon = document.getElementById('inicio-link-notification-icon');
            
            if (notificationElement && counters) {
              const totalPedidos = counters.total_pedidos_hoy || 0;
              const pedidosCocinados = counters.pedidos_cocinados || 0;
              const pedidosListosCocinar = counters.pedidos_listos_cocinar || 0;
              
              // Remove existing styles
              notificationElement.style.removeProperty('background');
              notificationElement.classList.remove('notification-warning', 'notification-success', 'notification-danger');
              if (totalPedidos > 0) {
                notificationElementIcon.style.setProperty('color', '#ffffff', 'important');
                if (pedidosListosCocinar > 0) {
                  // Red when pedidos_listos_cocinar > 0
                  notificationElement.style.setProperty('background', '#dc3545', 'important');
                  notificationElement.classList.add('notification-danger');
                } else if (totalPedidos > 0 && pedidosCocinados > 0 && totalPedidos === pedidosCocinados) {
                  // Green when total equals cocinados and both > 0
                  notificationElement.style.setProperty('background', '#28a745', 'important');
                  
                  notificationElement.classList.add('notification-success');
                } else if (totalPedidos !== pedidosCocinados && (totalPedidos > 0 || pedidosCocinados > 0)) {
                  // Orange when total != cocinados and at least one > 0
                  notificationElement.style.setProperty('background', '#ffb22b', 'important');
                  notificationElement.classList.add('notification-warning');
                }
                // No style change when both are 0
              }
            }
          }
        });
      }
    }
    
    // Try to initialize immediately
    initializeDailyOrdersChannel();
  });

  // CSS for counter animation
  const style = document.createElement('style');
  style.textContent = `
    .counter-updated {
      animation: pulse 0.5s ease-in-out;
      color:rgb(27, 27, 27) !important;
    }
    
    @keyframes pulse {
      0% { transform: scale(1); }
      50% { transform: scale(1.1); }
      100% { transform: scale(1); }
    }
    
    #daily-orders-container {
      transition: opacity 0.3s ease-in-out;
    }
  `;
  document.head.appendChild(style);