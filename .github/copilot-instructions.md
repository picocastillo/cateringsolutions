**ALWAYS UPDATE THIS FILE WHEN NEW CODE OR CHANGES ARE MADE**
**ALWAYS UPDATE THIS FILE WITH DIFFICULT FINDINGS AFTER TAKING TOO LONG TO UNDERSTAND OR FIX SOMETHING**

# Kiosk - AI Assistant Project Context

## Project Overview

**Kiosk** is a multi-tenant billing, inventory, and order management system for restaurants and catering businesses, built with Ruby on Rails. It handles the complete sales cycle from orders (pedidos) to invoicing (facturación) to payment collection (cobros), with full AFIP (Argentina tax authority) compliance.

## Technology Stack

- **Framework**: Rails 7.1.6
- **Ruby**: 3.4.8
- **Database**: MariaDB 10.11 (mysql2 gem)
- **Cache**: Redis (Dalli)
- **Test Suite**: RSpec 4.0 + FactoryBot + SimpleCov + parallel_tests
- **Background Jobs**: Delayed Job
- **File Storage**: Paperclip
- **Selenium Grid**: Docker Compose with 10 Chrome nodes (20 slots) for parallel system tests
- **Key Gems**:
  - `ar-enums` (~> 2.0) - Custom enumeration system
  - `danconia` - Money/currency handling
  - `audited` - Audit trail
  - `acts_as_discontinued` - Soft deletes
  - `cancancan` - Authorization
  - `virtus` - Value objects

## Core Domain Model

### Multi-Tenancy
- **Tienda**: Store/restaurant (tenant root)
- **Local**: Physical locations within a tienda
- **Cliente**: Customer companies
- **Cuenta**: Customer accounts (multiple per cliente)

### Sales Workflow

```
Pedido (Order) Lifecycle:
pendiente(1) -> aceptado(2) -> confirmado(3) -> finalizado(4) | cancelado(5)
     ↓              ↓               ↓
 Cart Edit    Factura Created   Stock Reduced
```

### Key Entities

**Pedidos (Orders)**
```ruby
# Estado flow: 1=pendiente, 2=aceptado, 3=confirmado, 4=finalizado, 5=cancelado
Pedidos::Pedido
  - belongs_to :tienda, :cuenta, :usuario, :autor, :local, :horario
  - has_many :productos_solicitados
  - has_many :comprobantes
  - enum :estado, class_name: 'Pedidos::Estado'
  
Key Methods:
  - aceptar/aceptar!: Move to estado 2, triggers comprobante creation
  - confirmar!(user): Move to estado 3, reduces stock, confirms comprobantes
  - reducir_stock_si_necesario: Stock reduction logic (checks @stock_ya_reducido flag)
  - cancelar!: Move to estado 5, creates nota de crédito
```

**Productos (Inventory)**
```ruby
Productos::Producto
  - belongs_to :categoria, :tienda
  - has_many :stocks (one per local)
  - has_many :precios (by cliente)
  - pesable: boolean (sold by weight, not units)
  
  Key Methods:
  - pesable_bloqueado?: true if categoria has stock_activo AND stocks with non-zero quantity exist, OR ProductoSolicitado records exist
    * Prevents pesable flag changes once product has stock or has been used in orders
  
  Validation:
  - pesable_no_modificable_si_en_uso: blocks pesable changes when pesable_bloqueado?

Productos::ProductoSolicitado (NOT Pedidos::ProductoSolicitado)
  - peso: decimal (weight in Kg, nil for non-pesable)
  - For pesable products: cantidad is ALWAYS 1, peso accumulates
  - importe_total: cantidad * peso * precio_unitario (= peso * precio when cantidad=1)
  - peso_total: cantidad * peso (= peso when cantidad=1)
  - When adding same pesable product again: peso += new_peso (not cantidad += 1)

Productos::Stock
  - belongs_to :producto, :tienda, :local (optional - can be nil)
  - has_many :stock_movimientos
  - cantidad_actual, cantidad_minima, cantidad_maxima
  
Key Methods:
  - aumentar_stock(cantidad, motivo = nil, usuario = nil)
  - reducir_stock(cantidad, motivo = nil, usuario = nil) # Creates StockMovimiento
  - ajustar_stock(nueva_cantidad, motivo = nil, usuario = nil)
  - stock_bajo?, sin_stock?, stock_critico?
  
Notes:
  - All stock methods accept optional usuario parameter for audit trail
  - When usuario is nil, movements display as "sistema"
  - When usuario is provided, movements track the actual user who made the change
  - local_id can be nil for single-location tiendas

Productos::StockMovimiento (Audit Trail)
  - tipos: 'entrada', 'salida', 'ajuste_entrada', 'ajuste_salida', 'venta', 'devolucion', 'transferencia'
  - tracks: cantidad, cantidad_anterior, cantidad_nueva, fecha, motivo, usuario_id
  - belongs_to :usuario, optional: true
  - Manual adjustments track current_user, automatic system changes have nil usuario
```

**Comprobantes (Invoicing)**
```ruby
# Base hierarchy
Comprobantes::Comprobante (abstract)
  └── Comprobantes::ComprobantePropio
      └── Ventas::Facturacion::Comprobante
          ├── Ventas::Facturacion::Factura
          ├── Ventas::Facturacion::NotaCredito
          └── Ventas::Facturacion::NotaDebito

Estado flow: pendiente(1) -> confirmado(2) -> finalizado(3)

Ventas::Facturacion::Comprobante
  - has_many :renglones (line items)
  - has_many :afectaciones (payment applications)
  - has_many :subtotales (tax breakdown)
  - belongs_to :tipo, :cuenta, :pedido, :local
  
Key Concepts:
  - Eventos System: confirmar, cobrar, pagar events in eventos/ subdirs
  - cargar_eventos "#{__dir__}/eventos" loads workflow
  - Automatic numeración via Infraestructura::GeneradorSecuencial

PDF Generation (Comprobante Ticket):
  - Uses acts_as_flying_saucer (XHTML2PDF via Flying Saucer/Nailgun)
  - Template chain: _comprobante.pdf.erb → _comprobante_false.pdf.erb
  - Partials: _encabezado.pdf.erb (header), _detalle.pdf.erb (products table),
    _totales.html.erb (total), _barcode_pedido.pdf.erb (barcode)
  - For venta_mostrador pedidos: medios de pago (Efectivo, QR, etc.) shown
    as subtotals between products table and total line
  - Access: comprobante.pedido.medios_pago (Pedidos::MedioPago model)
  - Pedidos::MedioPago: tipo (efectivo/debito/credito/qr/transferencia), importe, tipo_label
```

**Cobros (Payments)**
```ruby
Cobros::Recibo < Logistica::Flujos::FlujoEconomico
  - has_many :afectaciones (links to Comprobantes)
  - has_many :medios_pago (Efectivo, MercadoPago, etc.)
  - preparar_afectaciones: auto-distributes payment across pending invoices
```

**Cupones (Discount Coupons)**
```ruby
Cupones::Cupon
  - belongs_to :tienda, :grupo (Cupones::Grupo)
  - has_many :pedidos (applied via pedido.cupon_id)
  - enum :estado, class_name: 'Cupones::Estado'
  
Estado flow: activo(1) -> utilizado(2) | vencido(3) | cancelado(4)

Key Fields:
  - tipo_descuento: 'porcentaje' | 'monto_fijo'
  - valor_descuento: Decimal (e.g., 10.0 for 10% or $10)
  - limite_bonificacion: Max discount amount for percentage type
  - codigo: Unique alphanumeric code (e.g., 'ABC123')
  - fecha_vencimiento: Expiration date
  - cantidad_usos, maximo_usos: Usage tracking

Key Methods:
  - aplicable?: Checks activo?, not expired, not maxed out
  - calcular_descuento(importe): Returns discount amount respecting limits
  - marcar_utilizado!: Transitions to estado utilizado
```

**PedidoCocina (Kitchen Orders)**
```ruby
Pedidos::PedidoCocina
  - belongs_to :tienda, :usuario (creator), :local
  - has_many :pedidos (via pedido.pedido_cocina_id, dependent: :nullify)
  - has_many :productos_solicitados, through: :pedidos
  
Workflow:
  1. Admin visits /pedidos_cocina/new → sees confirmed pedidos grouped by client
  2. Selects pedidos via checkboxes → clicks "Crear" or "Buscar"
  3. find_pedidos action handles BOTH search (JS/turbo) and create (HTML)
  4. On create: PedidoCocina created, selected pedidos get pedido_cocina_id set
  5. Kitchen view shows grouped productos_solicitados for preparation

Key Controller Pattern (PedidosCocinaController#find_pedidos):
  - Single action handles two purposes via format negotiation:
    * JS request ("Buscar" button with data-remote): Returns search results
    * HTML request ("Crear" button, JS removes data-remote): Creates PedidoCocina
  - Uses makeFormNormal() JS function to toggle between modes
  - NEVER use `return` inside respond_to block (causes UnknownFormat error)
  
Query Filters:
  - horarios_de_corte_ids: Multi-select form field, submitted as Array
  - All query filters must handle both String and Array input
  - Must use compact_blank + any? guards for empty array submissions
```

**Pedidos Múltiples (Grouped Cart Orders)**
```ruby
Pedidos::PedidoMultiple
  - belongs_to :usuario
  - has_many :pedidos, dependent: :nullify

Key UX rules:
  - There is no explicit "+ Otro día" button on the pedido form.
  - Once a pedido has products, changing fecha creates/navigates to a sibling pedido in the same group.
  - Changing fecha on an empty pedido only changes that pedido's date.
  - If two pedidos with products share the same fecha, the UI highlights it as a duplicate-date warning.
  - The fecha datepicker highlights days that already have pedidos in the current group; the active pedido date uses a slightly stronger highlight. Emptying/removing the group clears those highlights.
  - "Vaciar Carrito" from either the pedido form or cart dropdown clears the entire group:
    * keeps the current pedido shell alive, empty, and ungrouped
    * destroys sibling pedidos in the group (and their productos_solicitados)
    * destroys the PedidoMultiple record
    * hides the "¿Más de un día?" fecha hint after the cart is emptied
```

**ProductoSolicitado Pricing (IMPORTANT)**
```ruby
Pedidos::ProductoSolicitado
  - precio_unitario: Original full price (never changes)
  - precio_con_descuento: Effective price after cupon discount
  - before_save :sincronizar_precio_con_descuento
  
Key Pattern: precio_con_descuento is ALWAYS populated:
  - When no discount: precio_con_descuento = precio_unitario
  - When cupon applied: precio_con_descuento = discounted price
  - This means SQL queries can always use precio_con_descuento directly (no COALESCE needed)

Key Methods:
  - precio_efectivo: Returns precio_con_descuento (use in Ruby display code)
  - tiene_descuento?: Returns precio_con_descuento < precio_unitario
  - importe_total: cantidad * precio_efectivo (for display, per ProductoSolicitado)
  - importe_total_sin_descuento: cantidad * precio_unitario

**Pedido#importe_total** (IMPORTANT):
  - When cupon present: `importe_total_sin_descuento - importe_descuento_cupon` (exact, no rounding)
  - When no cupon: `sum(precio_efectivo * cantidad)` per line item
  - This avoids the per-unit rounding issue where `round(target/qty, 2) * qty != target`
  - The per-item `precio_con_descuento` may have ±$0.01 rounding, but pedido total is always exact

# ❌ WRONG - Don't use precio_unitario for totals/sums
sum(precio_unitario * cantidad)

# ✅ CORRECT - Always use precio_con_descuento in SQL
sum(precio_con_descuento * cantidad)

# ✅ CORRECT - Always use precio_efectivo in Ruby
ps.precio_efectivo
```

## Critical Architecture Patterns

### 1. ArEnums Pattern (MOST IMPORTANT!)

**Never use** `.find()`, `.all()`, or method access for enums!

```ruby
# ❌ WRONG - Will fail
TasaIva.find(:iva_21)
Pedidos::Estado.pendiente
estado.method_name()

# ✅ CORRECT - Always use bracket notation
TasaIva[:iva_21]
Pedidos::Estado[:pendiente]
estado[:pendiente]

# Declaration
class TasaIva < ArEnums::Base
  enumeration do
    no_gravado alicuota: 0.0, desc: 'No Gravado', codigo: 3
    iva_21 alicuota: 21.0, desc: 'Gravado 21.0%', codigo: 5
  end
end

# Usage in models
enum :estado, class_name: 'Pedidos::Estado'
enum :tasa_iva, class_name: 'Impuestos::TasaIva', default: 0
```

### 2. Workflow/Events System

Models use event-driven state transitions via `Infraestructura::Eventos::Workflow`:

```ruby
# In model
class Comprobante < ComprobantePropio
  cargar_eventos "#{__dir__}/eventos"  # Loads confirmar.rb, cobrar.rb, etc.
end

# In eventos/confirmar.rb
module Ventas::Facturacion::Eventos
  class Confirmar < Evento
    enum :estado_generado, class_name: 'Comprobantes::Estado'
    
    def disparable?
      cbte.pendiente? && disparable_automatico?
    end
    
    def after_transition
      asignar_nro
      cbte.generar_afectaciones
      cbte.contabilizar
    end
  end
end
```

### 3. Stock Management Flow

**CRITICAL: Understanding Payment Flows and Stock Reduction**

There are **TWO distinct payment flows** in the system, each with different stock reduction timing:

#### Flow 1: Cuenta Corriente (Credit Account) - TWO-STEP PROCESS

For clientes with `cuenta_corriente` enabled:

```ruby
# Step 1: Customer finalizes pedido (PedidosController#finalizar)
1. Validates stock availability BEFORE accepting
2. pedido.aceptar! sets estado = 2 (aceptado)
3. pedido.reducir_stock_si_necesario IMMEDIATELY reduces stock
   └─> producto.reducir_stock(cantidad, local_id, 'venta')
       └─> StockMovimiento.create!(tipo: 'salida', motivo: 'venta', usuario: nil)
4. Comprobante created (factura pendiente)
5. Stock is ALREADY REDUCED at this point

# Step 2: Cron job runs at hora_corte (config/schedule.rb every 5 minutes)
Clientes::Cliente.confirmar_pedidos_aceptados
  └─> For pedidos with estado_id = 2 AND fecha < cliente.proximo_dia_pedido
      └─> Clientes::ConfirmarJob.perform_later(pedido.id)
          └─> pedido.confirmar!(nil)
              └─> Sets estado = 3 (confirmado)
              └─> Calls reducir_stock_si_necesario
                  └─> Checks @stock_ya_reducido flag
                  └─> SKIPS stock reduction (already done in aceptar!)
              └─> Confirms pending comprobantes
```

**Key Point:** Stock is reduced ONCE in step 1 (aceptar!), the confirmar! step checks the flag and skips duplicate reduction.

#### Flow 2: MercadoPago (Immediate Payment) - DIRECT CONFIRMATION

For clientes WITHOUT `cuenta_corriente`, payment happens before confirmation:

```ruby
# Single step: MercadoPago webhook callback (Pedido#imputar_pago)
1. MercadoPago sends payment confirmation webhook
2. pedido.imputar_pago(response) is called
3. if !confirmado? && !facturado?
     pedido.confirmar!(user)  # Direct to estado 3, skipping estado 2
     └─> Sets estado = 3 (confirmado)
     └─> Calls reducir_stock_si_necesario
         └─> @stock_ya_reducido is NOT set
         └─> REDUCES stock for the first time
             └─> StockMovimiento.create!(tipo: 'salida', motivo: 'venta', usuario: nil)
4. Creates and confirms comprobantes
5. Marks pedido as cobrado
```

**Key Point:** Stock is reduced ONCE in confirmar! because aceptar! was never called (payment flow skips estado 2).

#### Stock Reduction Prevention Mechanism

```ruby
# In Pedido model - uses DATABASE COLUMN not instance variable
def reducir_stock_si_necesario
  return if stock_reducido  # Database column prevents duplicate reduction
  
  productos_solicitados.each do |ps|
    # ... reduce stock logic
  end
  
  # Mark as reduced in database (persists across requests/jobs)
  update_column(:stock_reducido, true)
end
```

**Critical:** The `stock_reducido` boolean column in the `pedidos` table prevents duplicate stock reduction:
- Cuenta corriente flow: Stock reduced in `PedidosController#finalizar` after `aceptar!`, sets `stock_reducido = true`
- MercadoPago flow: Stock reduced in `confirmar!` during `imputar_pago`, sets `stock_reducido = true`
- Cron job: When `confirmar!` is called by background worker, checks `stock_reducido` column and skips if true

#### Stock Validation Points

```ruby
# 1. Before accepting pedido (cuenta corriente)
PedidosController#finalizar
  - Validates stock availability
  - Returns early with warning if insufficient
  - Only proceeds to aceptar! if stock is sufficient

# 2. Before generating payment (MercadoPago)
PedidosController#generar_pago_ml
  - Validates stock availability
  - Shows alert and redirects if insufficient
  - Only creates payment preference if stock is sufficient

# 3. On comprar page (both flows)
PedidosController#comprar
  - Shows warnings for pedidos with insufficient stock
  - Allows user to adjust quantities before finalizing
```

#### Manual Stock Adjustments

```ruby
# Through web interface (StocksController)
stocks_controller.ajustar_stock
  └─> stock.ajustar_stock(nueva_cantidad, motivo, current_user)
      └─> StockMovimiento.create!(tipo: 'ajuste_entrada/ajuste_salida', usuario: current_user)
```

#### Key Features

- **Supports nil local_id** for single-location tiendas
- **Tracks usuario** for manual adjustments, nil for automatic system changes
- **Integer display** throughout UI (15 not 15.0)
- **Stock reduced immediately** in aceptar! for cuenta corriente, or in confirmar! for MercadoPago
- **Prevents duplicate reduction** via @stock_ya_reducido flag
- **Prevents overselling** with validation before payment in both flows
- **Cron job** runs every 5 minutes to confirm cuenta corriente pedidos at hora_corte

#### Testing Patterns

```ruby
# Test cuenta corriente flow (existing in pedido_spec.rb)
- Creates cliente with cuenta_corriente enabled
- Finalizes pedido (aceptar!)
- Verifies stock reduced immediately
- Simulates cron job calling confirmar!
- Uses pedido.update_column(:stock_reducido, true) to simulate flag
- Verifies stock NOT reduced again (duplicate prevention)

# Test MercadoPago flow (covered in pedido_spec.rb)
- Simulates payment webhook
- Calls imputar_pago which triggers confirmar!
- Verifies stock reduced once in confirmar!
- Database column stock_reducido set to true
```

#### Common Gotchas

1. **Use database column, not instance variable** - `stock_reducido` persists across requests
2. **Never call reducir_stock directly** - Always use reducir_stock_si_necesario
3. **Check stock_reducido column** when testing to verify duplicate prevention
4. **Mock comprobante creation** in tests to isolate stock logic
5. **Use nil for local_id** in single-location tiendas
6. **Cuenta corriente reduces stock in finalizar** after calling `aceptar!`
7. **MercadoPago reduces stock in confirmar!** because it skips aceptar!
8. **Update stock in tests** - If categoria has stock_activo, producto creates stock with 0, update it to 100 for tests

### 4. Soft Deletes

```ruby
# Via acts_as_discontinued
modelo.discontinue!  # Sets discontinued_at
modelo.active?       # Checks discontinued_at.nil?
Model.active         # Scope for non-discontinued records
```

### 5. Authorization Pattern

```ruby
# Modular authorization in app/models/**/authorization.rb
class Productos::Authorization < Ability::Subrules
  def add_rules
    can :index, Producto if user.cliente?
    can [:read, :update], Producto do |p|
      p.tienda == user.tienda_activa
    end
  end
end

# All authorization files auto-loaded by Ability class
```

### 6. Multi-Tenant Scoping

```ruby
# Current user's active store
current_user.tienda_activa

# Controllers filter by tienda
productos = Producto.where(tienda: current_user.tienda_activa)

# Pedidos require local for stock operations
pedido.local = current_user.local  # Required!
```

## Testing Guidelines

> **For running tests, see `.github/skills/parallel-testing.md` — follow it EXACTLY.**
> Never manually call `parallel_rspec`, `rake parallel:*`, or rebuild databases.
> Use `./bin/ptest` for normal runs, `./bin/reset-and-test` after schema changes.

### Common Testing Patterns

```ruby
# Mock callbacks to isolate logic
allow(pedido).to receive(:crear_comprobante)

# Factory traits for Pedidos
create(:pedido, :with_productos)      # Pedido with productos_solicitados
create(:pedido, :aceptado)            # estado_id: 2
create(:pedido, :confirmado)          # estado_id: 3

# Estado transitions
pedido.aceptar!                       # 1 -> 2, creates comprobante
pedido.confirmar!(usuario)            # 2 or 3, reduces stock if needed

# Precio requires has_and_belongs_to_many relationship
precio = create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 150)

# Locales require all fields
Locales::Local.create!(nombre: 'Local Test', tienda: tienda, domicilio: 'Calle Test 123', telefono: '123456789')

# Cuenta factory defaults cuenta_corriente_parcial: true — override when testing non-CC flows:
create(:cuenta, cliente: cliente, cuenta_corriente_parcial: nil)
```

### Testing Stock Logic

```ruby
# Stock tests require proper setup
Productos::Stock.create!(producto: producto, tienda: tienda, local: local, cantidad_actual: 100, cantidad_minima: 10)

# Test duplicate reduction prevention
pedido.update_column(:stock_reducido, true)  # Simulates already-reduced flag
```

### Isolated (Single-Worker) Specs

Some specs are timing-sensitive and must run in a dedicated Selenium worker (not shared with others). They are listed in `ISOLATED_SPECS` in `bin/ptest` and passed as `--single` to `parallel_rspec`:

```
spec/system/daily_orders_real_time_spec.rb          # Action Cable timing
spec/system/pedidos_cocina_spec.rb                  # Shared PedidoCocina state
spec/system/pedidos/pedidos_multiples_options_validation_spec.rb  # copy-to-all reload
spec/system/pedidos/cart_dropdown_group_edit_spec.rb              # JS nav to sibling pedido
```

When a spec fails in the parallel run but passes in isolation (i.e., `bundle exec rspec spec/path/to/file_spec.rb` passes), add it to `ISOLATED_SPECS` in `bin/ptest`.

### Testing Real-Time Updates (Action Cable)

- WebSocket message delivery doesn't work in Capybara tests (process separation)
- Test JS functions directly: `page.execute_script('App.dailyOrders.updateCounters({...})')`
- Verify infrastructure: `App.cable.connection.isActive()` should be true
- `horario_corte_pedidos` must be in the PAST for test setup
- Delayed Jobs must be processed: `Delayed::Worker.new.work_off`

## Common Gotchas & Solutions

### 1. ProductoSolicitado Requires Precio AND Cuenta Association

```ruby
# ❌ Will fail: ProductoSolicitado validation requires pedido.cuenta.cliente
ProductoSolicitado.create!(pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 100)
# Error: "undefined method `cliente' for nil:NilClass" in asignar_precio callback

# Root cause: before_validation :asignar_precio tries to access pedido.cuenta.cliente
# but association chain isn't loaded when using create()

# ✅ Solution 1: Use asignar_cuenta_manual pattern (RECOMMENDED)
pedido = create(:pedido, tienda: tienda, cuenta: cuenta, fecha: Date.current,
                estado_id: 1, autor: usuario, usuario: usuario)
pedido.asignar_cuenta_manual  # Sets @asigno_cuenta_manual = true
pedido.cuenta = cuenta         # Explicitly reload association
pedido.save!
create(:producto_solicitado, pedido: pedido, producto: producto, 
       cantidad: 5, precio_unitario: 100)

# ✅ Solution 2: Skip validation (for tests only)
ps = ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 100)
ps.save(validate: false)

# ✅ Solution 3: Create precio with proper cliente association
precio = create(:precio, producto: producto, importe: 100, fecha_desde: Date.today)
precio.clientes << cuenta.cliente unless precio.clientes.include?(cuenta.cliente)
# Then create with proper pedido setup (use Solution 1)
```

### 2. ArEnums Syntax Errors

```ruby
# ❌ WRONG - sed command mistake
described_class[:symbol)  # Mismatched brackets

# ✅ CORRECT
described_class[:symbol]

# ❌ WRONG - Method access
estado.pendiente

# ✅ CORRECT
estado[:pendiente]
```

### 3. Stock Operations Support Optional Local

```ruby
# ✅ Works with local (multi-location tiendas)
pedido.local = autor.local
pedido.reducir_stock_si_necesario

# ✅ Also works without local (single-location tiendas)
pedido.local = nil
pedido.reducir_stock_si_necesario  # Uses local_id = local&.id

# Stock validation in controllers
validates_stock_availability  # Checks producto.stock_suficiente?(cantidad, local&.id)
```

### 4. Comprobante Creation Triggers

```ruby
# Callback triggers on estado change
after_save :crear_comprobante

# Set flag to control behavior
pedido.aceptar  # Sets @facturando = true
pedido.save!    # Triggers crear_comprobante

# In tests, mock to isolate
allow(pedido).to receive(:crear_comprobante)
```

### 5. Spec File Locations

```ruby
# Match directory structure
app/models/pedidos/pedido.rb     -> spec/models/pedidos/pedido_spec.rb
app/models/productos/stock.rb    -> spec/models/productos/stock_spec.rb
app/gateways/productos/stocks_importer.rb -> spec/gateways/productos/stocks_importer_spec.rb
```

### 6. NEVER Shadow Native Browser Globals in JavaScript

**CRITICAL: `app.js.erb` previously defined `var URL = function() {}` which OVERWROTE the browser's native `URL` constructor!**

This broke the MercadoPago SDK v2 (and potentially any library using `new URL(...)`) because:
- The SDK internally calls `new URL("https://api.mercadopago.com/v1/...")` 
- The overwritten `URL` returned a custom object with NO `searchParams` property
- Result: `TypeError: Cannot read properties of undefined (reading 'append')`

**Fix**: Renamed to `AppURL` (accessed via `App.url.*`, so no external API change).

**General Rule**: NEVER name custom classes/variables with the same name as browser built-in constructors (`URL`, `Request`, `Response`, `Headers`, `Event`, `Node`, `Element`, etc.) in global scope. Use `var` in Sprockets files = global scope = overrides `window.X`.

### 7. Checkout: opciones → comprar consolidation (May 2026)

**The separate `pedidos/:id/opciones` step has been merged into `pedidos/:id/comprar`.**

- Route `GET /pedidos/:pedido_id/opciones` now 301-redirects to `/comprar`.
- `POST .../finalizar_opciones` was removed entirely.
- All option fields (turno_entrega, enviar_a, direccion_envio, horario) live on the comprar page (`_pedido.html.erb`).
- `#turno_entrega_selector` and `#pedido_enviar_a_id` / `#pedido_direccion_envio` / `#pedido_horario_id` change handlers PATCH the pedido in place and re-fire `generar_pago_ml` (turno triggers a full reload because it can filter categories).
- Server-side validation lives inside `PedidosController#generar_pago_ml`. On failure it renders a JS response that disables the MP button (`mercadopago-button-disabled`) and shows `#mp-payment-validation-hint` with the error text. On success the MP preference is generated and rendered with `autoOpen: false` — the user must explicitly click the Pagar button to open the modal.
- `:opciones` and `:pagar_mercadopago_opciones` ability rules were removed; `:pagar_mercadopago` is the only remaining checkout authorization.
- `_boton_compra.html.erb` and `_pedido_en_curso.html.erb` cart links always point at `/comprar`.

**Testing implication:** to assert that an invalid option blocks payment, hit `POST .../generar_pago_ml` directly (xhr/JS format) and inspect the response body for `mp-payment-validation-hint` and `mercadopago-button-disabled`. The legacy `link_to method: :post` "Ir a Pagar" pattern no longer exists, and the `#confirmar_pedido` link on comprar is now CC-flow only.

**Pedidos múltiples parity (May 2026):** the resumen page (`/pedidos_multiples/:id/resumen`) now mirrors the same checkout option set per-pedido — turno, horario, enviar_a, direccion_envio. `PedidosMultiplesController#validation_errors_for(pedido)` is the single source of truth and is invoked by both `generar_pago_ml_multiple` (blocks MP preference creation, renders per-pedido `#mp-payment-validation-hint-{pid}` divs and a top-level `#mp-multiple-validation-summary` alert) and `finalizar_multiple` (CC flow, accumulates errors into a single redirect alert). MP button is rendered with `autoOpen: false` and never auto-clicked. When `@pedidos.size > 1` and a value is present, an "Aplicar a todos" button (`.rm-copy-to-all` with `data-field` = `turno_entrega_id|horario_id|enviar_a_id`) appears beside each selector — clicking PATCHes that value to all sibling pedidos and reloads.

### 8. JavaScript Click Handlers Override link_to method: :post

**CRITICAL: JavaScript intercepts Rails UJS links and modifies their href before submission!**

The `#confirmar_pedido` link on the comprar page (cuenta corriente flow) uses `link_to ... method: :post`
which relies on `rails-ujs` to create a hidden form and POST. JavaScript in
`app/assets/javascripts/pedidos/` intercepts the click and **appends query
parameters** (enviar_a_id, direccion, horario_id) from the current form field values
to the link's href before rails-ujs processes it.

```javascript
// In pedidos JS (click handler for #confirmar_pedido)
$(document).on('click', '#confirmar_pedido', function() {
  $(this).attr('href', $(this).attr('href') + '?enviar_a_id=' + ...);
});
```

**Impact on testing:**
- Setting a value via `update_column` in DB will be **OVERRIDDEN** by the JS-injected params
- Dropdown selectors only show valid options, so the JS always sends a valid value
- **You CANNOT test invalid submission through the UI** — use request specs instead

```ruby
# ✅ CORRECT - System test verifies UI prevents invalid selection
visit pedido_comprar_path(pedido)
options = page.all('#turno_entrega_selector option').map(&:text)
expect(options).not_to include('Invalid Turno Name')

# ✅ CORRECT - For MP-flow validation, hit generar_pago_ml directly
post generar_pago_ml_pedido_path(pedido), xhr: true, headers: { 'Accept' => 'text/javascript' }
expect(response.body).to include('mp-payment-validation-hint')
```

**General rule:** When `link_to` has `method: :post` AND there's JS attached
to its `id`, always check `app/assets/javascripts/` for click handlers that modify the href.
The JS-injected params take precedence over database values in the controller.

### 9. Multi-Select Form Fields Submit Arrays, NOT Strings

**CRITICAL: Query objects receiving params from multi-select `<select multiple>` forms get Arrays, not comma-separated Strings!**

The `query_form_for` helper generates GET forms with `q[]` namespace. Multi-select fields submit as `q[field_name][]` which Rails parses as an Array. However, some query objects assumed String input and called `.split(',')` — this crashes with `can't quote Array`.

```ruby
# ❌ WRONG - Crashes when form sends Array
def base_query
  ids = horarios_de_corte_ids.split(',').compact_blank
  scope.where(horario_id: ids)
end

# ✅ CORRECT - Handle both String (URL params) and Array (form submit)
def base_query
  ids = (horarios_de_corte_ids.is_a?(String) ? horarios_de_corte_ids.split(',') : horarios_de_corte_ids).compact_blank
  return scope unless ids.any?
  scope.where(horario_id: ids)
end
```

**Also critical:** Always add `.compact_blank` + `.any?` guards. `ApplicationController#clean_empty_string_in_arrays` strips blanks but multi-selects with no selection still submit `[""]`, which `.present?` considers truthy.

**Affected queries:** `ProductosSolicitadosQuery`, `PedidosQuery` — any query with `horarios_de_corte_ids`, `horario_corte_cliente_ids`, or `horario_corte_cuenta_ids` filters.

### 9. NEVER Use `return` Inside `respond_to` Block

```ruby
# ❌ WRONG - `return` exits the method before Rails executes format handlers
def find_pedidos
  respond_to do |format|
    if condition
      return format.html { redirect_to ... }  # Exits method, Rails never sees the format
    end
    format.js { ... }
  end
end
# Result: ActionController::UnknownFormat for HTML requests

# ✅ CORRECT - Use if/else inside respond_to, no return
def find_pedidos
  respond_to do |format|
    if condition
      format.html { redirect_to ... }
    else
      format.html { render ... }
    end
    format.js { ... }
  end
end
```

### 10. `cambiar_cuenta` Must Update `cuenta_id` When Usuario Changes

**CRITICAL: When admin changes the usuario on the pedido edit form, `cambiar_cuenta` must also update `cuenta_id` to match the new usuario's cuenta.**

The `cambiar_cuenta` controller action uses `update_all` (bypasses callbacks) to persist changes. Previously, changing the usuario only updated `usuario_id` and `pedido_para_empresa`, leaving `cuenta_id` stale. This caused:
- Products loaded from the WRONG client's catalog (via `@cuenta_activa = @pedido.cuenta`)
- Wrong pricing shown in product cards
- Checkout page displaying old cuenta info

The fix: when `usuario_id_changed?`, also include `cuenta_id` in the `update_all`:
```ruby
elsif @pedido.usuario_id_changed?
  updates[:pedido_para_empresa] = false
  updates[:usuario_id] = @pedido.usuario_id
  updates[:cuenta_id] = @pedido.usuario.cuenta_id if @pedido.usuario&.cuenta_id
end
```

**Note:** The `asignar_cuenta` callback on `Pedido#save` would eventually fix the cuenta during `finalizar`, but:
1. The intermediate state (product catalog, checkout) would be wrong
2. The fix relies on a fragile chain: `cambiar_cuenta.js.erb` → triggers `selectpicker` change → fires `cambiar_categoria` AJAX → `@pedido.save` → `asignar_cuenta` — this chain can break depending on page configuration.

### 11. `Cliente` Has No `tienda_id` (HABTM Only) — Step 8/9 Migration

**As of Apr 25, 2026, `clientes.tienda_id` is GONE.** Cliente↔Tienda is exclusively HABTM via `clientes_tiendas`. A single cliente row can be shared across multiple tiendas (e.g. "Sancor Salud" in tiendas 1 and 2 is now ONE row, not two).

```ruby
# ❌ WRONG - column no longer exists
Clientes::Cliente.where(tienda: tienda)
Clientes::Cliente.where(tienda_id: tienda.id)

# ✅ CORRECT - use the disponibles_en scope
Clientes::Cliente.disponibles_en(tienda)
# = joins(:tiendas).where(tiendas: { id: tienda }).distinct

# ✅ Legacy compat shims (use sparingly):
cliente.tienda      # returns tiendas.first
cliente.tienda = t  # assigns self.tiendas = [t]
```

**Cuenta uniqueness:** `cuentas.nro` is now globally unique (DB-level `index_cuentas_on_nro_unique` + model-level `validates :nro, uniqueness: true`). Tests that previously did `update_all(nro: X)` to force a collision will now hit the unique index.

**SQL ambiguity:** When using HABTM joins, `nombre` becomes ambiguous (`clientes.nombre` vs `tiendas.nombre`). Always qualify: `where('clientes.nombre LIKE ?', ...)`.

**Factory pattern (spec/factories/clientes.rb):**
```ruby
# Transient :tienda key still works for backward compat
create(:cliente, nombre: 'Foo', tiendas: [tienda_a, tienda_b])
create(:cliente, nombre: 'Bar', tienda: tienda)  # → tiendas: [tienda]
```

**Step 9 dedup migration** (`20260427100000_consolidate_duplicate_clientes`): merges duplicate cliente rows by `(LOWER(TRIM(nombre)), cuit)`, rewrites all `cliente_id` FKs in `cuentas`, `configuraciones_impositivas`, `clientes_pedidos_cocina`, `clientes_categorias`, `clientes_precios`, and unions HABTM access for `clientes_tiendas`, `clientes_turnos_entrega`, `descuentos_venta_mostrador_clientes` (all have UNIQUE `(cliente_id, other_id)` indexes — uses INSERT IGNORE + DELETE pattern). Idempotent.

### 12. Pedidos Index Hides Pending Pedidos (`no_pendientes = true`)

**CRITICAL: The pedidos index filters out pending pedidos (estado_id=1) by default!**

The `PedidosController#index` sets `@query.no_pendientes = true` when no `estado_id` filter is provided. This applies to ALL users (admins AND clients). Pending pedidos are only visible when the `estado_id` filter is explicitly applied (but the UI only shows aceptado/confirmado/cancelado in the dropdown — no "pending" option).

**Impact on system tests:**
- `find('a[href*="pedido"][data-method="delete"]')` will fail if you create a PENDING pedido and visit `pedidos_path` — the pedido won't appear in the table
- The `.ti-trash` icon found by `have_css('.ti-trash')` on the index page is from the **cart dropdown** (hidden), NOT the table — this causes "element not visible" errors
- Use **ACCEPTED pedidos (estado=2)** for index-based destroy tests — they appear by default

```ruby
# ❌ WRONG — pending pedido won't appear in the index table
pedido = build_pedido(estado_id: 1)
visit pedidos_path
find("a[href='#{pedido_path(pedido)}'][data-method='delete']")  # fails

# ✅ CORRECT — accepted pedido appears in the default index
pedido = build_pedido(estado_id: 1)
pedido.update_column(:estado_id, 2)  # accepted
visit pedidos_path
find("a[href='#{pedido_path(pedido)}'][data-method='delete']", wait: 10)  # works
```

### 13. `agregar_al_multiple` Has No HTML Link — Triggered by JS Fecha Change

**There is no `a[href*="agregar_al_multiple"]` link in any view.** The route `POST /pedidos/:id/agregar_al_multiple` is triggered indirectly:
1. User changes `#pedido_fecha` on the edit form
2. JS fires `cambiar_cuenta` AJAX
3. Server detects fecha changed on a pedido with products
4. Creates sibling via the `agregar_al_multiple` logic and sets `@redirigir_a`
5. `cambiar_cuenta.js.erb` does `window.location.href = '@redirigir_a'`

**Test pattern (from `pedidos_multiples_spec.rb`):**
```ruby
page.execute_script("$.onmount(); $('#pedido_fecha').val('#{fecha2.strftime('%d/%m/%Y')}').trigger('change')")
expect(page).to have_current_path(%r{/pedidos/(?!#{pedido.id}/edit)\d+/edit}, wait: 15)
```

### 14. Stale `public/assets` Can Shadow Current JS in System Tests

**CRITICAL: System tests may serve precompiled `public/assets/application-*.js` before Sprockets compiles current source assets.**

This caused `pedidos_multiples.js` changes to be invisible in Selenium: the browser loaded a stale digest asset that did not contain `enviar_a_selector_` handlers, so selecting "Domicilio Particular" on the pedidos multiples resumen page never toggled `direccion-envio-wrap-*`.

```bash
# Detect whether test browser is probably seeing stale assets
find public/assets -maxdepth 1 -name 'application-*.js'

# Fix before rerunning system tests
RAILS_ENV=test bundle exec rails assets:clobber
```

**Symptom pattern:** Rails runner/Sprockets says `application.js` includes the new JS, but Selenium page source or fetched `/assets/application-*.js` does not. Clobber `public/assets`, restart Selenium if needed, then rerun focused system specs.

### 13. Inicio Stock Alerts Include Accepted Pedido Projection

Inicio stock alerts now show a future-looking stock calculation for accepted pedidos:

```ruby
stock_actual_menos_aceptados = stock.cantidad_actual - suma_productos_solicitados_en_pedidos_aceptados
```

Rules:
- Only subtract `Pedidos::Estado[:aceptado]` pedidos from the active tienda.
- For multi-local tiendas, stock alerts and accepted-pedido subtraction are scoped to `current_user.local_activo`.
- For pesable products, subtract `cantidad * peso`; otherwise subtract `cantidad`.
- The Inicio panel shows the column `Stock - Pedidos Aceptados` in critical/low stock tables.
- Products that are currently above minimum but would fall to minimum or below after accepted pedidos appear in `Stock Comprometido por Pedidos Aceptados`.

### 14. `Proceso.create!` Requires Both `autor:` AND `tienda:` Fields

When creating any `Infraestructura::Procesos::Proceso` subclass (exporters, importers) directly (e.g. in tests or rails runner), you must pass both:

```ruby
exp = Ventas::Facturacion::VentasPorCategoriaExporter.create!(
  autor: user,
  tienda: user.tienda_activa,   # ← required! validates presence
  params: { q: { ... } }
)
```

`query_params[:user]` is auto-injected from `autor` via `Exporter#query_params` — do NOT put the user object inside `params[:q]` (YAML serialization will raise `Psych::DisallowedClass`).

### 15. write_xlsx 1.15.0 Chart API — 4 Critical Bugs

**write_xlsx 1.15.0** is the latest available gem. It has 4 subtle chart API bugs that cause silent/cryptic failures:

#### Bug 1: `xl_rowcol_to_cell` missing in Chart
`Chart` base class doesn't include `CellReference`. `Chart::SeriesData#process_names` calls `xl_rowcol_to_cell` when `name:` is an array.

```ruby
# ❌ WRONG — raises NoMethodError: undefined method 'xl_rowcol_to_cell'
chartsheet.add_series(name: [sheetname, row, col], ...)

# ✅ CORRECT — use plain string
chartsheet.add_series(name: 'Category Name', ...)
```

#### Bug 2: `add_chartsheet` doesn't exist
`WriteXLSX` has no `add_chartsheet` method.

```ruby
# ❌ WRONG
chartsheet = @workbook.add_chartsheet('Gráfico')

# ✅ CORRECT — add_chart(type:, subtype:) WITHOUT embedded: true returns a Chartsheet
chartsheet = @workbook.add_chart(type: 'column', subtype: 'stacked')
```

#### Bug 3: Wrong array argument order causes 2D ranges → nil crash
`xl_range_formula(sheetname, row_1, row_2, col_1, col_2)` — rows first, then cols.
If you use wrong order, ranges become 2D → `get_chart_range` returns nil → `formula_data[id]` stays nil → `each_with_index for nil` crash on serialization.

```ruby
# ❌ WRONG — [sheetname, row_start, col_start, row_end, col_end]
categories: [TABLA_SHEET_NAME, 0, 2, 0, last_col]

# ✅ CORRECT — [sheetname, row_1, row_2, col_1, col_2], row_1==row_2 for 1D horizontal range
categories: [TABLA_SHEET_NAME, 0, 0, 2, last_col]
values:     [TABLA_SHEET_NAME, row_index, row_index, 2, last_col]
```

#### Bug 4: `chartsheet.chart` undefined (attr_writer only, no reader)
`Chartsheet` has `attr_writer :chart` but no reader. All chart methods are delegated directly.

```ruby
# ❌ WRONG — NoMethodError: undefined method 'chart' for Chartsheet
chart = chartsheet.chart
chart.add_series(...)

# ✅ CORRECT — call methods directly on chartsheet (delegated via def_delegators :@chart)
chartsheet.add_series(...)
chartsheet.set_title(name: 'Title')
chartsheet.set_x_axis(name: 'X')
chartsheet.set_y_axis(name: 'Y')
chartsheet.set_style(10)
```

#### Verified working `build_chart` pattern:

```ruby
TABLA_SHEET_NAME = 'Ventas por Categoría'.freeze

def build_chart(meses, categorias)
  last_col   = 1 + meses.size
  chartsheet = @workbook.add_chart(type: 'column', subtype: 'stacked')

  categorias.each_with_index do |cat, i|
    row_index = i + 1  # row 0 is header
    chartsheet.add_series(
      name:       cat,
      categories: [TABLA_SHEET_NAME, 0, 0, 2, last_col],
      values:     [TABLA_SHEET_NAME, row_index, row_index, 2, last_col]
    )
  end

  chartsheet.set_title(name: 'Ventas por Categoría y Mes')
  chartsheet.set_x_axis(name: 'Mes')
  chartsheet.set_y_axis(name: 'Importe ($)')
  chartsheet.set_style(10)
end
```

**Must use `optimization: false`** when creating the workbook: `WriteXLSX.new(path, optimization: false)` — chart sheets require random access to worksheet cell data.

### 16. Envío a Domicilio Must Persist on `change`, Not Just on Address `blur`

**CRITICAL: Selecting "Domicilio Particular" in the checkout `Enviar A` dropdown must persist `envio_a_domicilio = true` immediately — relying on the address-field `blur` to persist it leaves the pedido as "enviar a la empresa" at payment time.**

Affects clientes with `usuario_puede_elegir_cuenta: true` AND `permitir_envios_a_domicilio: true` (employees of a company who can deliver to the empresa OR to their home). The `change` handler on `#pedido_enviar_a_id` in [app/assets/javascripts/pedidos/pedidos.js](app/assets/javascripts/pedidos/pedidos.js) was asymmetric:
- **empresa branch** (`val !== '-1'`): persisted via `patchPedidoAndRefireMp(pid, { enviar_a_id })`.
- **domicilio branch** (`val === '-1'`): ONLY toggled UI (`#wraper-direccion`, `.total-*`), no PATCH. The only domicilio-persist path was the `blur` on `#pedido_direccion_envio` (`{ enviar_a_id: -1, direccion_envio }`). If blur didn't fire (race with payment, focus never left the field), MercadoPago was charged/delivered to the empresa.

**3-part fix:**
1. **JS** (`pedidos.js` `change` handler, domicilio branch): immediately `patchPedidoAndRefireMp(pid, { enviar_a_id: -1, direccion_envio: <current address value> })`.
2. **Model** (`pedido.rb` `direccion_cargada` validation): added `return if pendiente?` so a draft cart can hold `envio_a_domicilio = true` with a blank `direccion_envio` (the address is enforced at checkout, not on the draft). Without this, persisting `enviar_a_id = -1` before typing an address would fail validation and never save.
3. **Controller** (`pedidos_controller.rb#generar_pago_ml`): added `@validation_errors << 'Ingresá la dirección de envío a domicilio.' if @pedido.envio_a_domicilio && @pedido.direccion_envio.blank?` — keeps the MP button disabled with a hint until the address is provided (parity with `PedidosMultiplesController#validation_errors_for`).

**Testing:** `spec/system/pedidos/envio_domicilio_mercadopago_spec.rb` stubs `Mercadopago::SDK` and captures the preference payload to assert the `'Envío a domicilio'` line item + correct `external_reference`. Added to `ISOLATED_SPECS` in `bin/ptest` (AJAX/reload timing-sensitive).

## Database Schema Key Points

### Important Tables

```ruby
# pedidos - Orders
- estado_id: 1=pendiente, 2=aceptado, 3=confirmado, 4=finalizado, 5=cancelado
- tienda_id, cuenta_id, usuario_id, autor_id, local_id
- fecha (delivery date), venta_mostrador (POS sale flag)
- facturado, cobrado (billing status flags)

# productos_stocks - Inventory
- producto_id, tienda_id, local_id (unique together)
- cantidad_actual, cantidad_minima, cantidad_maxima
- Updated via transactional stock_movimientos

# productos_stock_movimientos - Audit trail
- tipo: entrada/salida/ajuste_entrada/ajuste_salida/venta/devolucion
- cantidad, cantidad_anterior, cantidad_nueva
- fecha, motivo, usuario_id

# comprobantes - Invoices/receipts/credit notes
- type (STI): Ventas::Facturacion::Factura, NotaCredito, Cobros::Recibo
- estado_id: 1=pendiente, 2=confirmado
- tipo_id (refs tipos_comprobantes), nro, letra
- cuenta_id, tienda_id, pedido_id, local_id

# afectaciones - Payment applications
- comprobante_id (payer), afectado_id (payee)
- importe (amount applied)
- Links Recibos to Facturas

# renglones - Invoice line items
- comprobante_id, producto_id, categoria_id
- cantidad, precio_unitario, tasa_iva_id
```

## Code Organization

### Directory Structure

```
app/
├── models/
│   ├── clientes/        # Customer management
│   ├── cobros/          # Payment collection (Recibo)
│   ├── comprobantes/    # Base invoice classes
│   ├── impuestos/       # Tax configuration (AFIP)
│   ├── pedidos/         # Order management
│   ├── productos/       # Inventory & products
│   ├── tiendas/         # Multi-tenant stores
│   ├── usuarios/        # User management
│   └── ventas/
│       └── facturacion/ # Invoicing (Factura, NotaCredito)
├── controllers/         # RESTful controllers (match model namespaces)
├── gateways/           # External integrations & import/export
│   ├── productos/      # Stocks importer/exporter
│   └── excel_importer.rb
├── services/           # Business logic services
│   └── redis_service_client.rb
├── queries/            # Complex queries (SearchObject pattern)
└── validators/         # Custom validators

lib/
├── exceptions.rb       # Custom exceptions
├── infraestructura/    # Framework extensions
│   ├── generador_secuencial.rb  # Auto-numbering
│   └── eventos/        # Workflow system
└── tasks/
    └── quality.rake    # Coverage & testing tasks
```

### Naming Conventions

```ruby
# Models: Match module structure
module Productos
  class Stock < ApplicationRecord
  end
end

# Controllers: Namespaced
module Productos
  class StocksController < ApplicationController
  end
end

# Routes: Scoped
scope module: :productos do
  resources :stocks do
    put :ajustar_stock, on: :member
    get :movimientos, on: :member
  end
end

# Specs: Mirror structure
spec/models/productos/stock_spec.rb
spec/controllers/productos/stocks_controller_spec.rb
spec/requests/productos/stocks_spec.rb
```

## Money & Currency Handling

```ruby
# Use Danconia::Money for all currency
importe = Danconia::Money.new(1000)  # 1000.00 in default currency

# Display formatting
importe.to_s         # "$1,000.00"
importe.pretty       # "1,000.00"

# Calculations
subtotal = renglones.map(&:precio_total).sum
total = Danconia::Money.new(subtotal)
```

## Background Jobs

```ruby
# Delayed Job configuration
config.action_mailer.deliver_later_queue_name = 'fast'

# Usage
handle_asynchronously :method_name, queue: 'slow'

# Job classes
class MyJob < ApplicationJob
  queue_as :default
end
```

## Date & Time Handling

```ruby
# Configuration
config.time_zone = 'Buenos Aires'
config.active_record.default_timezone = :local

# Usage
Time.current         # Rails preferred
Date.today          # Current date
Time.zone.today     # Time-zone aware
```

## Environment-Specific Behavior

```ruby
# Redis databases
production: 0
test: 2
development: 1

# Email configuration
config.action_mailer.asset_host = 'http://localhost:3000'

# Exception notifications
ExceptionRecipients = ['sebachavarini@gmail.com']
```

## Deployment & DevOps

```ruby
# Capistrano deployment
bundle exec cap production deploy

# Scheduled tasks (whenever gem)
# config/schedule.rb manages cron jobs

# Database management
bundle exec rails db:schema:dump  # Export schema
bundle exec rails db:schema:load  # Load schema
```

## Quick Reference Commands

```bash
# Development
rails s                          # Start server
rails c                          # Console
rails db:migrate                 # Run migrations

# Testing (see .github/skills/parallel-testing.md for full details)
./bin/ptest unit                 # Parallel unit tests (20 workers, ~44s)
./bin/ptest system               # Parallel system tests (10 workers, ~3min)
./bin/ptest all                  # Unit + system (~4min)
./bin/reset-and-test all         # Full reset + all tests (after schema changes)
bundle exec rspec spec/path/file_spec.rb:42  # Single test/line

# Code Quality
rake quality:rubocop             # Lint check
rake quality:rubocop_fix         # Auto-fix linting
```

## Import/Export Patterns

```ruby
# Excel Import (via Spreadsheet gem)
class Productos::StocksImporter < ExcelImporter
  def import_row(row)
    # Process each row
  end
end

# Excel Export
class Productos::StocksExporter < ExcelExporter
  def export
    # Generate spreadsheet
  end
end

# Usage in controllers
def import
  importer = Productos::StocksImporter.new(file: params[:file])
  importer.import!
end
```

## Recommendations for AI Assistants

### When Working with This Codebase

1. **Always check ArEnums syntax** - Use `[:symbol]` not `.method` or `.find()`
2. **Mock callbacks in tests** - `allow(model).to receive(:callback_method)` to isolate logic
3. **Create proper test data** - Locales need domicilio + telefono, ProductoSolicitado needs precio
4. **Check multi-tenancy** - Most operations need tienda_activa context
5. **Stock operations support nil local** - local_id can be nil for single-location tiendas
6. **Use transactional stock changes** - Always go through Stock#reducir_stock, never update cantidad_actual directly
7. **Pass usuario for audit trail** - Manual stock changes should pass current_user, system changes use nil
8. **Follow module namespacing** - Keep controllers, models, specs in matching namespaces
9. **Respect soft deletes** - Use .active scope and discontinue! method
10. **Display integers for stock** - Use `.to_i` for cantidad_actual display (15 not 15.0)

### When Adding Tests

1. **Check existing factory definitions** in `spec/factories/`
   - Use `:with_productos` trait for pedidos with productos_solicitados
   - Use `:aceptado`, `:confirmado` traits for estado transitions
   - Use `:for_cliente` trait for precios with cliente association
2. **Mock callbacks** - `allow(pedido).to receive(:crear_comprobante)` isolates stock logic
3. **ProductoSolicitado requires asignar_cuenta_manual**:
   ```ruby
   pedido = create(:pedido, tienda: tienda, cuenta: cuenta, fecha: Date.current, estado_id: 1)
   pedido.asignar_cuenta_manual  # Critical!
   pedido.cuenta = cuenta
   pedido.save!
   create(:producto_solicitado, pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 150.0)
   ```
4. **Create Stock records** with local_id (or nil for single-location tiendas)
5. **Usuario setup for system tests**:
   ```ruby
   user = create(:usuario, :admin, visualizando_tienda: tienda)
   user.tiendas << tienda unless user.tiendas.include?(tienda)
   ```
6. **Action Cable system tests**:
   - horario_corte_pedidos must be `(Time.current - 1.minute).strftime('%H:%M')`
   - Process delayed jobs: `Delayed::Worker.new.work_off`
   - WebSocket delivery doesn't work in Capybara, test JS directly via `page.execute_script`
   - Verify infrastructure: `App.cable.connection.isActive()` should be true
7. **Run coverage** - `rake quality:coverage` after adding tests

### When Debugging

1. Check `log/development.log` for SQL queries
2. Use `rails c` to test ArEnums syntax interactively
3. Verify `usuario.tienda_activa` is set correctly
4. Check `audits` table for change history via `audited` gem
5. Look for `discontinued_at` if records seem missing

---

## Maintenance Guidelines

### When to Update This Documentation

**Update REQUIRED when:**
- ✅ Adding new architectural patterns (e.g., new event system, service objects)
- ✅ Changing core workflows (pedido lifecycle, facturacion flow, stock management)
- ✅ Adding/removing major gems or dependencies
- ✅ Coverage increases by 5%+ or reaches milestone (50%, 60%, 70%, 80%)
- ✅ Rails/Ruby version upgrades
- ✅ New gotchas discovered that break tests or cause confusion
- ✅ Authorization patterns change
- ✅ Multi-tenancy logic changes

**Update NICE-TO-HAVE when:**
- ⚡ New testing patterns emerge
- ⚡ Database schema has significant changes
- ⚡ New import/export patterns added
- ⚡ API integrations added (MercadoPago, AFIP, etc.)

### How to Update

**Ask an AI Assistant:**
```
"Update .github/copilot-instructions.md with:
- New XYZ pattern I just implemented in [file]
- Current test coverage is now X%
- Document the new [feature] workflow"
```

**Manual Updates:**
1. Edit the file directly in `.github/copilot-instructions.md`
2. Update version numbers, coverage %, and date at bottom
3. Add new patterns to "Critical Architecture Patterns"
4. Update examples if syntax/APIs changed

**Review Schedule:**
- 📅 After major features (before merging to main)
- 📅 Monthly quick review of coverage % and gotchas
- 📅 Quarterly comprehensive review

### Maintenance Checklist

Copy this to your PR template or keep in your project notes:

```markdown
## Documentation Maintenance

- [ ] Coverage changed? Update coverage % and date
- [ ] New architectural pattern? Add to Critical Architecture Patterns
- [ ] New gotcha encountered? Add to Common Gotchas section
- [ ] Major refactor? Review affected sections
- [ ] New testing pattern? Add to Testing Guidelines
- [ ] Dependencies changed? Update Technology Stack
```

### Quick Health Check

Run these commands to verify doc accuracy:

```bash
# Check current coverage
rake quality:coverage

# Check Ruby/Rails versions
ruby -v
bundle exec rails -v

# List major gems
grep "gem '" Gemfile | grep -v "#" | head -20

# Check if key patterns still exist
grep -r "enum.*class_name" app/models/ | wc -l  # Should show ArEnums usage
grep -r "cargar_eventos" app/models/ | wc -l    # Should show Workflow usage
```

### Version History

| Date | Summary |
|---|---|
| Jun 8, 2026 | **Envío a domicilio not persisted before MercadoPago payment**: clientes with `usuario_puede_elegir_cuenta` + `permitir_envios_a_domicilio` (empleados de empresa) who picked "Domicilio Particular" were still charged/delivered to the empresa. Root cause: `#pedido_enviar_a_id` `change` handler in `pedidos.js` only persisted the empresa branch; the domicilio branch (`val === '-1'`) merely toggled UI and relied on the address `blur` to PATCH — if blur didn't fire, `envio_a_domicilio` stayed `false` at payment. 3-part fix: (a) JS change handler now PATCHes `{ enviar_a_id: -1, direccion_envio: <current> }` immediately on domicilio select; (b) `Pedido#direccion_cargada` gained `return if pendiente?` so a draft cart can hold `envio_a_domicilio = true` with blank address; (c) `PedidosController#generar_pago_ml` adds `'Ingresá la dirección de envío a domicilio.'` validation to keep the MP button disabled until address provided. New spec `spec/system/pedidos/envio_domicilio_mercadopago_spec.rb` (stubs `Mercadopago::SDK`, captures preference payload), added to `ISOLATED_SPECS` in `bin/ptest`. See Common Gotchas #16. |
| May 27, 2026 | **Cancelar pedido NotaCredito local fallback + carrito-first local priority**: `Pedido#cancelar!` was raising `Local Debe tener local de venta` when canceling a confirmed pedido whose factura had `local = nil` AND whose `usuario.tienda_activa.multiple_locales?` was true (typical for cross-tienda historical facturas). Root cause: `Ventas::Facturacion::NotaCredito.generar_nc_pedido` → `preparar_para_cancelar_a` only copies `pedido/cuenta/automatico/fecha_emision` (no `local`). `Confirmar.after_transition` sets `cbte.autor = pedido.usuario`, which then triggers `verificar_local`. Fix (final priority after user feedback — pedido and carrito take precedence over autor): (a) `Ventas::Facturacion::Comprobante#cachear_local` fallback chain is `pedido.local → cancela_a.local → autor.local_activo → tienda.local_para_carrito` (early-return if `local` already set); (b) `Pedido#asignar_tienda` and `Pedido#imputar_pago` fallback chain is `tienda.local_para_carrito → autor.local_activo` (carrito wins over user's active local because the store-level carrito setting represents intent for new pedidos); (c) `Pedido#anular_factura` sets `nc.local ||= local || comprobante.local || u&.local_activo` as belt-and-suspenders. Also added regression spec for `#imputar_pago` with unknown user in external_reference (locks the `user && (...)` guard from 2026-05-13 against `NoMethodError` on `user.operador?`). Specs: 6 new in `spec/models/ventas/facturacion/comprobante_spec.rb` (`#cachear_local fallback chain`), 1 new in `spec/models/pedidos/pedido_spec.rb` (`#imputar_pago with missing user`). |
| May 16, 2026 | **PedidosMultiples skip empty-shell pedidos + Bug A–E hardening**: When a user visits `/pedidos_multiples/:id/resumen`, `_pedido_en_curso.html.erb` cart partial auto-creates an empty pendiente shell pedido (no cuenta, no productos_solicitados) that gets pulled into `@grupo.pedidos`. Both `finalizar_multiple` and `generar_pago_ml_multiple` iterated `@grupo.pedidos.select(&:pendiente?)` and called `validation_errors_for(pedido)` on this shell — returned `['El pedido no tiene cuenta asignada.']` → redirect to /resumen with alert. Fix: filter via `.reject { \|p\| p.productos_solicitados.empty? }` at all 3 iteration sites in `PedidosMultiplesController` (validation loop, items build loop, pedidos_pendientes in finalizar_multiple). Also in this session: (a) **Bug B** `ProductoSolicitado#pedido_must_be_pendiente_for_changes` validator gained dirty-field guard so it only fires on cantidad/precio_unitario/precio_con_descuento/peso/producto_id changes (was blocking legitimate aceptar transitions); `sincronizar_precio_con_descuento` before_save now returns early unless `pedido&.pendiente?`. (b) **Bug D** `Pedido#anular_factura` early-returns when comprobante already fully credited (prevents NotaCredito duplication). (c) `config/schedule.rb` daily 6am `data_fixes:print_gap_summary` rake entry. Regression: 2266 unit examples (0 failures, 5 pendings) + 409 system examples (0 failures). |
| May 13, 2026 | **Ventas por Categoría XLSX export**: Added `Ventas::Facturacion::VentasPorCategoriaExporter` (`app/gateways/ventas/facturacion/ventas_por_categoria_exporter.rb`). Overrides `run` (pivot table, not row-per-record). Uses `optimization: false` for WriteXLSX (required for chart sheets). Sheet 1: pivot table — rows = categorias sorted ASC + "TODAS" totals row, cols = Categoría \| TOTALES \| month-year (from date filters, max 36 months). Sheet 2: stacked column chart via `build_chart`. Data: SUM of `renglones.precio_unitario * cantidad [* peso]` signed by `tipos_comprobantes.debitan`. `search_scope` returns ComprobantesQuery relation (for progress counting). Controller: `ComprobantesController#index` now has `respond_to` with `format.xls`. View: `export_link(Ventas::Facturacion::Comprobante, path: comprobantes_path(..., format: :xls))` — visible only to admins (CanCan block rules return true for class-level checks in cancancan 3.x). `compute_data` scoped by `local_id` when `tienda.multiple_locales?`. AJAX filter sync: `comprobantes/index.js.erb` updates `.export-link` href after filter form submit. **write_xlsx 1.15.0 chart API** (4 critical bugs — see Common Gotchas #15). `Proceso.create!` requires both `autor:` AND `tienda:` fields. |
| May 8, 2026 | **`verificar_local` must skip for pendiente pedidos**: The `verificar_local` validation fires for ALL estados on tiendas with `multiple_locales: true`. When `cambiar_cuenta` creates a sibling pedido (fecha-change path), it passes `tienda:` explicitly, so `asignar_tienda` returns early and never sets `local = autor.local`. Result: `RecordInvalid: Local Debe tener local de venta` in production. Fix: (1) add `return if pendiente?` to `verificar_local` — consistent with all other draft-cart validators (`fecha`, `cuenta`, `productos_solicitados` all have `unless: :pendiente?`); (2) pass `local: @pedido.local \|\| current_user.local` in the sibling `create!` in `cambiar_cuenta` so the pedido has a local when it transitions beyond pendiente; (3) `salir_del_multiple` used `update!(pedido_multiple_id: nil)` which runs full validations — switched to `update_column` since unlinking from a group is a pure metadata change that never needs model validation (also fixed the `miembros.each` line that triggered the same error on the surviving last member). Regression: `spec/models/pedidos/pedido_spec.rb` `#verificar_local` (3 examples) + `spec/system/pedidos/pedidos_multiples_delete_sibling_spec.rb` (4 examples). |
| May 8, 2026 | **Sibling pedido `create!` must pass `no_validar_fecha: true`**: `cambiar_cuenta` creates a sibling pendiente pedido with `fecha: nueva_fecha` — but that fecha may be a past date (user changed to yesterday's date before deleting all products). `fecha_valida` fires on the `create!` and raises `RecordInvalid: Fecha inválida`. Fix: compute the next valid weekday that is not already taken in the group and >= `proximo_dia_pedido`. Specifically: `fecha_sibling = [nueva_fecha, proximo].max; fecha_sibling += 1.day while fecha_sibling.saturday? \|\| fecha_sibling.sunday? \|\| fechas_ocupadas.include?(fecha_sibling)`. This avoids bypassing validation entirely. Do NOT add `return if pendiente?` to `fecha_valida` — that would silently ignore invalid fecha selections by real cliente users on the cart form. Also fixed: `usuario.cliente.proximo_dia_pedido` in the error message → `usuario&.cliente&.proximo_dia_pedido` (safe navigation, prevents crash if `usuario` is an admin). Regression: `spec/models/pedidos/pedido_spec.rb` `#fecha_valida` (2 examples). |
| May 8, 2026 | **`authorization.rb` CanCan blocks must nil-guard `x.cuenta`**: `can(:aceptar, ...)` and `can(:pagar_mercadopago, ...)` blocks in `pedidos/authorization.rb` called `x.cuenta.cuenta_corriente_habilitada?` without nil protection. When an admin creates a fresh pedido (before choosing a client, or via admin-only group flow), `x.cuenta` is nil. CanCan evaluates these blocks whenever `can?(:pagar_mercadopago, @pedido_pendiente)` is called (e.g. in `_pedido_en_curso.html.erb` navbar). Result: `NoMethodError: undefined method 'cuenta_corriente_habilitada?' for nil` — which Rails renders as a 500 that looked like "authorization error" to the user. The same nil could also surface when deleting a sibling pedido from a group (the redirect re-renders the navbar). Fix: `:aceptar` → `x.cuenta&.cuenta_corriente_habilitada?`; `:pagar_mercadopago` → `x.cuenta.present? && !x.cuenta.cuenta_corriente_habilitada?`. TDD: `spec/system/pedidos/pedidos_multiples_delete_sibling_spec.rb` (4 examples, 0 failures — covers both admin and cliente × delete on a 3-pedido group). |
| May 7, 2026 | **`cuando_validar_usuario?` must skip validation for admin-authored pedidos**: The `validates :usuario, presence` on `Pedidos::Pedido` was firing when `cuando_validar_usuario?` returned true for admin-created pedidos with `usuario: nil`. Root cause: condition only checked `!pendiente? && !venta_mostrador && !pedido_para_empresa`, not *who* created it. Admins legitimately create pedidos for cuentas without a specific usuario (bulk ordering). Fix: add `&& autor&.cliente?` so validation only fires for cliente-authored pedidos. **UI changes**: Para column in pedidos index now shows sibling pedidos from the same PedidoMultiple group as "Grupo: dd/mm dd/mm" links with `data-turbolinks: false` (cross-tienda auto-handled by existing `load_pedido_with_includes` switcher). **UX fix**: fecha datepicker scroll-jump on `cambiar_cuenta.js.erb` AJAX fixed using `requestAnimationFrame` + `document.documentElement.style.overflowAnchor = 'none'` pin pattern. Regression spec: `spec/system/pedidos/pedidos_multiples_admin_cc_spec.rb` (3 examples, 0 failures). |
| May 6, 2026 | **`verificar_local` used `autor.tienda_activa` instead of `tienda`**: In cross-tienda PedidoMultiple flows, a confirmed pedido that belongs to tienda A (multiple_locales: false) can have an autor whose `tienda_activa` is tienda B (multiple_locales: true). Calling `valid?` on that pedido (e.g. in PedidosCocinaController) fired `verificar_local` because it checked `autor.tienda_activa.multiple_locales?` rather than the pedido's own `tienda.multiple_locales?`. Fix: changed to `tienda&.multiple_locales?`. | Sequel to the previous fix. After auto-switching `visualizando_tienda_id` and reloading `current_user`, the candidato pedido was already loaded via `includes(:autor, :usuario)` BEFORE `update_columns`, so `@pedido.autor` and `@pedido.usuario` are stale `Usuarios::Usuario` instances whose `:visualizando_tienda` association still points at the SOURCE tienda. `verificar_local` validation reads `autor.tienda_activa.multiple_locales?` — when the source tienda has `multiple_locales: true` and the cross-tienda pedido has no `local`, validation fails → `@pedido.valid?` returns false → `_productos_en_venta.html.erb` `<% if @pedido.valid? %>` guard renders the entire span empty → no menu-del-día / mas-productos / opciones-del-dia panels visible (only `<span id="productos-en-venta"></span>` in HTML). Fix: when `@pedido.autor_id == reloaded.id` reassign `@pedido.autor = reloaded` (and same for `usuario`). Regression spec asserts the bug with `multiple_locales: true` on the source tienda. |
| May 6, 2026 | **Cross-tienda pedido auto-switch must FULL-RELOAD current_user**: `PedidosController#load_pedido_with_includes` auto-switches `visualizando_tienda_id` when a cliente edits a sibling pedido in another tienda. Previously called `update_columns + unmemoize_all + association(:visualizando_tienda).reset`, but `Authentication#login_from_session` preloads `:tienda_cliente, :visualizando_tienda` via `.includes(...)`. In production, the in-memory user object's `visualizando_tienda` association object stayed stale → `tienda_activa` returned the OLD tienda → view rendered with wrong tienda flags (`muestra_menus_del_dia?`, `soporta_productos_diarios?` etc.) → menu-del-día panel never rendered until manual refresh. Fix: replace `@current_authenticated_user` AND `@current_user` with a freshly-reloaded `Usuarios::Usuario.where(id:).includes(...).first`. Regression spec: `spec/system/pedidos/cross_tienda_menu_diario_spec.rb`. |
| May 5, 2026 | **MercadoPago double-button fix**: When `usuario_puede_elegir_cuenta: true`, `App.onMount('#show-pedido')` called `$('#pedido_enviar_a_id').change()` programmatically to initialise DOM visibility. The change handler's `else` branch called `patchPedidoAndRefireMp()` → PATCH → `refireGenerarPagoMl()`, firing a second concurrent `generar_pago_ml` AJAX. Both async `co.render()` calls then targeted the same `'#mp-boton-container'` ID selector and inserted two MP buttons. Fix: replaced `$('#pedido_enviar_a_id').change()` with an IIFE that only updates DOM visibility (show/hide `#wraper-direccion`, `.total-simple`, `.total-con-envio`) without calling `patchPedidoAndRefireMp`. Regression spec: `spec/system/pedidos/mercadopago_button_single_render_spec.rb`. |
| May 5, 2026 | **PedidosMultiples MP two-click fix**: The resumen page `generar_pago_ml_multiple.js.erb` previously used `co.render()` which inserted a second MercadoPago-branded button inside `#mp-boton-container` after the user clicked the green "Pagar" `button_to`. The user had to click again to open the MP checkout. Fix: replaced `autoOpen: false` + `co.render()` with `autoOpen: true` (no `co.render()`). The MP modal now opens automatically on the first click. A "Redirigiendo..." processing indicator fills `#mp-boton-container` while the modal loads. Testable via `window.mpCheckoutAutoOpened` flag set before `new MercadoPago()`. Regression spec: `spec/system/pedidos/pedidos_multiples_mp_single_click_spec.rb`. |
| May 5, 2026 | **Admin tienda switcher bug fix**: `cambiar_tienda_activa` was NOT in `TiendasController`'s `load_and_authorize_resource except:` list. CanCan auto-called `authorize! :cambiar_tienda_activa, Tienda` before the action ran, which raised `AccessDenied` for regular admins (they only have `can(:cambiar_tienda, Tienda)`, not `:cambiar_tienda_activa`). Fix: added `:cambiar_tienda_activa` to the `except` list AND added explicit `authorize! :cambiar_tienda_activa, @tienda` in the cliente branch (required by `check_authorization` in `ApplicationController`). Admin branch already had `authorize! :cambiar_tienda, @tienda`. New specs: `spec/system/tiendas/admin_tienda_switcher_spec.rb` + `spec/requests/tiendas/admin_switcher_spec.rb`. Key gotcha: `check_authorization` fires if ANY action skips `authorize!` — adding to `except` list requires adding explicit `authorize!` call in the action body. |
| May 4, 2026 | Added `pedidos_multiples_options_validation_spec.rb` and `cart_dropdown_group_edit_spec.rb` to `ISOLATED_SPECS` in `bin/ptest` — both are timing-sensitive JS/AJAX specs that failed intermittently under parallel Selenium load (copy-to-all PATCH + reload, and cart dropdown navigation to sibling pedido). |
| May 3, 2026 | **System test fixes (4 failures → 0)**: (1) `rm-copy-to-all` buttons in resumen.html.erb now only render when `pedido.turno_entrega_id.present?` / `pedido.horario_id.present?` — previously they appeared on ALL pedidos whenever `@pedidos.size > 1`, breaking tests that asserted the sibling-with-no-value never shows the button. (2) Restored `fecha: dia` filter in `PedidosController#new` cliente path (needed so the cupon_edge_cases spec doesn't pick up another pending pedido). (3) `cambiar_tienda_activa` now sets `fecha: current_user.cuenta&.proximo_dia_pedido` when retagging an empty shell so the `fecha: dia` filter in `#new` can find it. (4) `ClientesController#create` is now excluded from `load_and_authorize_resource`, builds `@cliente` from params, attaches `tienda_activa`, and calls `authorize!` manually — fixes "creado correctamente" test that was hitting an authorization 403. |
| May 3, 2026 | **Cross-tienda PedidoMultiple support**: a single open `PedidoMultiple` group can now span multiple tiendas the cliente has access to. Cart dropdown (`_pedido_en_curso.html.erb`) does a 2-step pendiente lookup: prefer pendiente in active tienda, fallback to any pendiente with `pedido_multiple_id IS NOT NULL` (surfaces cross-tienda group). `PedidosController#new` auto-attaches a freshly-created pendiente to the user's open group (`PedidoMultiple.abiertos` scope, capped at `MAX_PEDIDOS`). `TiendasController#cambiar_tienda_activa` retags an empty cliente cart-shell to the new tienda (no orphan pendientes); pedidos with productos stay put and a fresh shell is created in the new tienda that auto-enrolls in the same group. `PedidosMultiplesController#validation_errors_for` now uses `pedido.tienda` (not `tienda_activa`). Resumen page shows tienda iniciales tooltip per pedido. New `PedidoMultiple.abiertos` scope + `#abierto?` predicate (uses `Pedido.uncached` to bypass query cache). New spec `spec/requests/pedidos/cross_tienda_multiple_spec.rb`. 2236 unit examples, 0 failures. |
| May 2, 2026 | **PedidoMultiple cuenta-ownership**: `pedidos_multiples.usuario_id` is now nullable; new `cuenta_id` FK added (migration `20260501100000`). `PedidoMultiple` validates "at least one of usuario or cuenta". Authorization updated so cliente users can read groups owned by their cuenta. `PedidosController` passes `cuenta:` when creating new groups. Resumen view falls back to `@grupo.cuenta` when pedido has no cuenta. `PedidoMultiple` spec updated: `belong_to(:usuario).optional`, `belong_to(:cuenta).optional`, new validation examples. |
| May 1, 2026 | Pedidos múltiples cart cleanup: `Vaciar Carrito` from the pedido form or cart dropdown now clears the whole group, keeps the current pedido as an empty ungrouped shell, destroys grouped sibling pedidos and their `productos_solicitados`, and destroys the `PedidoMultiple` record. Selenium coverage added for both buttons. |
| May 1, 2026 | Inicio stock alerts now subtract accepted pedidos (`Pedidos::Estado[:aceptado]`) from current stock in a `Stock - Pedidos Aceptados` column and add a `Stock Comprometido por Pedidos Aceptados` warning for products that will become low when those pedidos confirm. |
| May 1, 2026 | System tests can silently serve stale precompiled `public/assets/application-*.js`; clobber with `RAILS_ENV=test bundle exec rails assets:clobber` when Selenium ignores current JS. Also made pedidos multiples resumen `enviar_a_selector_*` handler delegated/namespaced so domicilio toggle works reliably with hidden/bootstrap-select inputs. |
| Apr 25, 2026 | **Step 8/9 clientes-shared migration**: dropped `clientes.tienda_id` (HABTM `clientes_tiendas` is now sole link), added `validates :nro, uniqueness: true` + DB unique index `index_cuentas_on_nro_unique`, added `Cliente#disponibles_en(tienda)` scope, legacy `cliente.tienda` reader/writer shims. Step 9 (`20260427100000_consolidate_duplicate_clientes`) merges duplicate cliente rows (e.g. "Sancor Salud" in 2 tiendas → 1 row × 2 tiendas), rewrites `cliente_id` FKs across all child tables, unions HABTM access using INSERT IGNORE pattern for unique-join tables. 2156 examples, 0 failures. |
| Apr 24, 2026 | Toast system rewrite: replaced legacy qTip2-based `growl()` with `app/assets/javascripts/toast.js` powered by Motion One v10.18.0 (vendored at `vendor/assets/javascripts/motion.min.js`). New API: `toast.show / .success / .error / .warning / .info / .saved / .product / .stockError`. Cart additions/removals show product image via `data-imagen` on `#input_cantidad_*` (added in `_panel_productos.html.erb` + `_productos_diarios_panels.html.erb`). Per-type animated SVG icons (success checkmark draws itself, error wobbles, cart-remove arrow nudges, warning bang flashes). Square corners (per UI pref). Mobile: top-anchored, swipe-to-dismiss, 3-toast cap. `window.growl` shim preserved for any missed call sites. Old `growl.js` and `#growl-container` SCSS removed from the asset pipeline. |
| Apr 24, 2026 | Capacity bump after server upgrade to 8 vCPU / 8 GB: Puma `workers 3 → 5` (5×5 = 25 concurrent req), DJ `fast 2 → 3` pool. confirmacion stays at 2 (advisory-locked). Action items left for the server: set `MALLOC_ARENA_MAX=2` in the puma-kiosk systemd unit, raise MariaDB `innodb_buffer_pool_size` to 2G and `max_connections` to 256. |
| Apr 24, 2026 | `Clientes::ConfirmarJob` now wraps work in a MariaDB advisory lock (`GET_LOCK('kiosk:confirmar_pedido:#{id}', 0)`) so the cron's re-enqueues and multiple workers never process the same pedido concurrently. `confirmar_pedidos_aceptados` capped to `.limit(500)`. confirmacion DJ pool bumped 1 → 2 in `config/deploy.rb` (safe because of `with_lock` + `stock_reducido` flag + advisory lock). |
| Apr 22, 2026 | Inicio dashboard `stats_usuarios_chart` ("Productos por Mes") and `stats_admin_importes_chart` ("Ventas por Mes") widgets had NO caching and grouped by day in Ruby — now SQL monthly `GROUP BY DATE_FORMAT(fecha, '%Y-%m')` + `Rails.cache.fetch` 5 min TTL keyed by `[widget, tienda_id, local_id, Date.current]` |
| Apr 23, 2026 | `MenusDiarios::Tipo.find_by(id:)` raises `NoMethodError` (ArEnums has no AR finders) — broke calendar JSON for any tienda with a menu, looked like "menu disappeared" to user; use `[:symbol]` lookup |
| Apr 23, 2026 | MenuDiario form: enum `default: 1` made `tipo_id.present?` always true on `new`, so disabled-select + hidden field posted `tipo_id=1` even on PD-only tiendas — fix uses `persisted?` check before honoring stored tipo |
| Mar 31, 2026 | cambiar_cuenta must update cuenta_id when usuario changes |
| Mar 17, 2026 | Venta Mostrador PDF medios de pago subtotals |
| Mar 9, 2026 | PedidoCocina bugs: Array quoting, respond_to return, empty filters |
| Mar 2026 | Pesable (weight-based) products for Ventas Mostrador POS |
| Mar 8, 2026 | Daily dollar exchange rate table (`cotizaciones_dolar`), replaced `tiendas.precio_dolar` |
| Feb 17, 2026 | Post-upgrade perf fix: latin1 charset mismatch, N+1 fixes, Redis caching |
| Feb 16, 2026 | Rails 5.2→7.1.6, Ruby 2.7→3.4.8, CoffeeScript removal |
| Feb 15, 2026 | importe_total rounding fix for cupon discounts |
| Feb 14, 2026 | Performance optimization (7 phases), JS click handler gotcha |
| Feb 13, 2026 | Cupones discount system, precio_con_descuento always populated |
| Nov 20, 2025 | Parallel testing infrastructure (20 workers, SimpleCov, Selenium Grid) |
| Nov 6, 2025 | Payment flows docs, stock_reducido DB column (replaced instance var) |
| Nov 5, 2025 | Action Cable testing, stock management, initial docs |

---

**Last Updated**: Jun 8, 2026
**Coverage Status**: ~71.5% line coverage (2266 unit examples + 409 system examples, 0 failures, 5 pendings) - Target: 80%
**Rails Version**: 7.1.6
**Ruby Version**: 3.4.8
**MariaDB Version**: 10.11.9
