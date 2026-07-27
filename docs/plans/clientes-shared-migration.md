# Plan: Shared Clientes / Cuentas / Usuarios Across Tiendas

> **Status:** Draft / awaiting approval
> **Scope:** Convert per-tienda Clientes / Cuentas / Usuarios into globally shared entities, gated by an explicit `clientes ↔ tiendas` access list. Preserve per-tienda Pedidos, Comprobantes, Productos, Cupones, Categorías, Stocks.
> **Estimated effort:** ~5–7 weeks of focused work + 1–2 weeks regression hardening.

---

## 0. Current snapshot (production-equivalent local DB)

| Entity | Count |
|---|---|
| Tiendas | **3** |
| Clientes | **101** |
| Cuentas | **154** |
| Usuarios | **5,490** |

Duplicates discovered (read-only audit):

| Check | Result | Action needed |
|---|---|---|
| Cliente `nombre` duplicates | 2 names: `Consumidor Final` (tiendas 2 & 3, ids 10 / 65), `Sancor Salud` | Merge or rename |
| Cliente `cuit` duplicates | 4 CUITs repeated (each twice) | **Merge** — same legal entity in two tiendas |
| Usuario `login` duplicates | **0** | None — safe to make global ✅ |
| Usuario `email` duplicates | **0** | None — safe to make global ✅ |
| Usuario `dni` duplicates | 3× DNI `0`, 2× `12312312`, 2× `30811225` | Clean placeholder/typo data |
| Cuenta `nro` collisions | 2 (the seed `nro=1` and `nro=2`) | Re-number after migration via new generator |

This is a much smaller mess than feared — the user-table is essentially already global-ready.

---

## 1. Goals & non-goals

### Goals
1. `Clientes::Cliente`, `Clientes::Cuenta`, `Usuarios::Usuario` become **global** (no `tienda_id` column on `clientes`; no per-tienda uniqueness scopes).
2. New explicit relation `clientes ↔ tiendas` (HABTM `clientes_tiendas`) — a cliente is "available" in a tienda only if linked.
3. New `tiendas.permitir_login_clientes` boolean — login portal can disable client logins per-tienda.
4. A login attempt on `tienda.dominio` succeeds only if (a) tienda allows client logins AND (b) the user's cliente is linked to that tienda.
5. `Cuenta.nro` (and any other cliente-side codes) are re-issued from a new **global** `GeneradorSecuencial` scope so codes are unique across all tiendas.
6. New "tienda activa" switcher for **client users whose cliente is linked to >1 tienda** (radio-button style at the top of `pedidos/new`).
7. Pedido index for those multi-tienda client users shows pedidos from all their tiendas, with a `tienda` column.
8. **Admin `Clientes` and `Usuarios` index views must be filtered to entities linked to the admin's `tienda_activa`** — even though clientes/usuarios are now global rows, an admin only sees the ones whose cliente has a `clientes_tiendas` link to their active tienda. Avoids cross-tienda data leakage.

### Non-goals (explicitly stay per-tienda)
- `Pedidos::Pedido`, all `Comprobantes::*`, `Cupones::Cupon`, `Productos::Producto`, `Productos::Categoria`, `Productos::Stock`, `Locales::Local`, `Pedidos::PedidoCocina`. These remain `belongs_to :tienda`.
- AFIP comprobante numbering stays `tienda#{id}_{ClassName}` (legal/fiscal requirement).
- Producto codes stay per-tienda.
- Authorization isolation between tiendas (admins only see their tiendas).

---

## 2. Architecture overview

```
Tienda                 Cliente                 Cuenta             Usuario
  │  has_many             │  has_many             │  has_many        │
  │  :clientes,           │  :cuentas             │  :usuarios       │
  │  through:             │                       │                  │
  │  :clientes_tiendas    │                       │                  │
  └─────── HABTM ─────────┘                       │                  │
                                                                     │
Tienda has_many :usuarios, through: :cuentas → :usuarios (derived)   │
                                                                     │
Usuario.tiendas_disponibles =                                        │
   cuenta.cliente.tiendas where tienda.permitir_login_clientes       │
                                                                     │
Usuario.tienda_activa = visualizando_tienda (now used for BOTH       │
   admin and cliente users; falls back to first tiendas_disponibles) │
```

Key idea: **`visualizando_tienda_id` becomes the single source of truth for "active tienda"** for every kind of user. The current split `cliente? ? tienda_cliente : visualizando_tienda` goes away. `tienda_cliente_id` is kept only as the user's "primary" / default tienda for backward compatibility and for picking the initial active tienda after login.

---

## 3. Data-migration phase (do this BEFORE shipping any code change)

### 3.1 Reconcile cliente duplicates (manual SQL / rails console review)
- For each duplicate `cuit` group: pick the canonical cliente, re-point its cuentas/comprobantes/pedidos/cupones, then `discontinue!` the dup. Script lives in `lib/tasks/clientes_merge.rake` (see § 11).
- "Consumidor Final" is a **special case** — every tienda has one for venta_mostrador. Either:
  - Keep one shared "Consumidor Final" (id 10) and re-point tienda 3 references to it (recommended), OR
  - Rename them `Consumidor Final - {tienda.nombre}` and treat them as distinct legal entities.
  - **Recommendation:** keep one shared. Add cliente↔tienda link for both tiendas.

### 3.2 Clean placeholder DNI rows
- Set DNI=NULL where DNI=0 or obviously bogus (`12312312`, `30811225` if confirmed test data).

### 3.3 Snapshot
- `mysqldump` of pre-migration state stored in `tmp/backup_pre_shared_clientes_YYYYMMDD.sql`.

---

## 4. Schema migrations (in order)

```ruby
# db/migrate/XXXXX_add_permitir_login_clientes_to_tiendas.rb
add_column :tiendas, :permitir_login_clientes, :boolean, default: true, null: false
```

```ruby
# db/migrate/XXXXX_create_clientes_tiendas.rb
create_table :clientes_tiendas, id: false do |t|
  t.references :cliente, null: false, foreign_key: true
  t.references :tienda,  null: false, foreign_key: true
end
add_index :clientes_tiendas, [:cliente_id, :tienda_id], unique: true
add_index :clientes_tiendas, [:tienda_id, :cliente_id]
```

```ruby
# db/migrate/XXXXX_backfill_clientes_tiendas.rb (data migration)
def up
  Clientes::Cliente.find_each do |c|
    next unless c.tienda_id
    ActiveRecord::Base.connection.execute(
      "INSERT IGNORE INTO clientes_tiendas (cliente_id, tienda_id)
       VALUES (#{c.id}, #{c.tienda_id})"
    )
  end
  # Manually link merged "Consumidor Final" / "Sancor Salud" / dup-CUIT
  # canonical clientes to BOTH tiendas (handled by clientes:merge rake).
end
```

```ruby
# db/migrate/XXXXX_remove_tienda_from_clientes.rb
remove_foreign_key :clientes, :tiendas if foreign_key_exists?(:clientes, :tiendas)
remove_index  :clientes, :tienda_id    if index_exists?(:clientes, :tienda_id)
remove_column :clientes, :tienda_id, :integer
```

```ruby
# db/migrate/XXXXX_renumber_cuentas_global.rb (data migration, see § 5)
```

> Keep `usuarios.tienda_cliente_id` for now (used as default active tienda after login). Drop in a follow-up migration once verified unused.

---

## 5. New code-generation strategy

### Cuenta.nro — currently per-tienda, becomes **global**
- File: [app/models/clientes/cuenta.rb](../../app/models/clientes/cuenta.rb) line 205.
  ```ruby
  # OLD
  self.nro = Infraestructura::GeneradorSecuencial.proximo("tienda#{cliente.tienda.id}_cuentas_contables")
  # NEW
  self.nro = Infraestructura::GeneradorSecuencial.proximo("global_cuentas_contables")
  ```
- Add `validates :nro, uniqueness: true` (was implicit).
- Re-numbering data migration (run after backfill, before lifting per-tienda scope):
  ```ruby
  # Re-issue nros in id order, seed the generator afterward
  ActiveRecord::Base.transaction do
    next_nro = 0
    Clientes::Cuenta.order(:id).each do |c|
      next_nro += 1
      c.update_columns(nro: next_nro)
    end
    Infraestructura::GeneradorSecuencial
      .find_or_create_by(scope: 'global_cuentas_contables')
      .update!(ultimo: next_nro)
  end
  ```

### Other generators — **NO change**
| Generator scope | Verdict |
|---|---|
| `tienda#{id}_pedidos-cocina`, `tienda#{id}_categorias-venta`, `tienda#{id}_productos-venta`, `tienda#{id}_grupos-cocina` | Stay per-tienda |
| `tienda#{id}_Ventas::Facturacion::Factura`, `…NotaCredito`, `…NotaDebito`, `…Recibo` | Stay per-tienda (AFIP) |

### Cliente — does not currently use a generator; no change required.

---

## 6. Model changes

### `Tiendas::Tienda`
- Add `has_and_belongs_to_many :clientes` (join `clientes_tiendas`).
- Add `has_many :usuarios_clientes, through: :clientes` (cliente → cuentas → usuarios).
- Existing `has_and_belongs_to_many :usuarios` (admin join `usuarios_tiendas`) stays.

### `Clientes::Cliente`
- Drop `belongs_to :tienda`.
- Add `has_and_belongs_to_many :tiendas` (join `clientes_tiendas`).
- Validation:
  ```ruby
  validates :nombre, uniqueness: { case_sensitive: false }   # was scoped to :tienda_id
  validates :cuit,   uniqueness: true, allow_blank: true     # NEW
  ```
- Method:
  ```ruby
  def disponible_en?(tienda) = tiendas.exists?(tienda.id)
  def multi_tienda?         = tiendas.size > 1
  ```
- `categorias` HABTM stays per-tienda (categories live in a tienda; a cliente in 2 tiendas just sees both catalogues filtered by `tienda_activa`).
- `precios` HABTM unchanged.

### `Clientes::Cuenta`
- Unchanged structurally (still `belongs_to :cliente`).
- New global `nro` generator (§ 5).
- `validates :nro, uniqueness: true`.

### `Usuarios::Usuario`
- `belongs_to :tienda_cliente` becomes `optional: true` and is repurposed as **default/home tienda** only.
- New method:
  ```ruby
  # Tiendas where this user is allowed to log in / shop right now.
  def tiendas_disponibles
    return Tiendas::Tienda.active if super_admin?
    if cliente?
      cuenta&.cliente&.tiendas&.where(permitir_login_clientes: true) || Tiendas::Tienda.none
    else
      tiendas.where(activo: true) # admin: existing usuarios_tiendas join
    end
  end

  def tienda_activa
    visualizando_tienda || tiendas_disponibles.first
  end

  def puede_loguearse_en?(tienda)
    return false unless tienda&.permitir_login_clientes || !cliente?
    tiendas_disponibles.exists?(tienda.id)
  end
  ```
- Validations:
  - `dni` uniqueness becomes global with `allow_nil: true` after cleaning placeholders.
  - `login` / `email` already globally unique in DB — make the model validation match.

### `Pedidos::Pedido`
- No structural change — pedido remains `belongs_to :tienda`.
- `verificar_tienda(t)` still compares `tienda_id == t.id`.

### Authorization (`*/authorization.rb`)
- Replace every `c.tienda == user.tienda_activa` with a method on the entity:
  - `Cliente`: `user.tiendas_disponibles.intersect?(c.tiendas)` (Ruby 3.1+ `Enumerable#intersect?`).
  - `Cuenta`: `user.tiendas_disponibles.intersect?(c.cliente.tiendas)`.
  - `Usuario`: target user's `tiendas_disponibles` overlaps with `user.tiendas`.
  - `Pedido`, `Comprobante`, `Producto`, etc.: still strict `entity.tienda == user.tienda_activa` (these are per-tienda).

---

## 7. Login flow changes

### `app/controllers/shared_controller.rb#buscar_tienda_activa`
```ruby
def buscar_tienda_activa
  if current_user
    current_user.tienda_activa
  else
    Tiendas::Tienda.find_by(dominio: request.domain(2)) || Tiendas::Tienda.first
  end
end
```
After login, set `visualizando_tienda` if it is nil or not in `tiendas_disponibles`.

### Devise `after_set_user_path` (or `SessionsController#create` override)
Add a guard:
```ruby
tienda_actual = Tiendas::Tienda.find_by(dominio: request.domain(2))
if resource.cliente?
  unless tienda_actual&.permitir_login_clientes
    sign_out resource
    flash[:alert] = "El portal de #{tienda_actual&.nombre} no acepta logins de clientes en este momento."
    return redirect_to new_user_session_path
  end
  unless resource.puede_loguearse_en?(tienda_actual)
    sign_out resource
    flash[:alert] = "Tu cuenta no tiene acceso a #{tienda_actual.nombre}."
    return redirect_to new_user_session_path
  end
  resource.update_columns(visualizando_tienda_id: tienda_actual.id) if resource.visualizando_tienda_id != tienda_actual.id
end
```
A clean place to put this is a new concern `app/controllers/concerns/cliente_login_guard.rb` invoked from a Devise hook or `after_action :enforce_tienda_login, only: :create` in the Devise controller subclass.

---

## 8. Client-facing tienda switcher (multi-tienda clientes only)

### Where it lives
At the top of `pedidos/new` (and re-shown on `pedidos/comprar` for safety) — only when `current_user.cliente? && current_user.cuenta.cliente.multi_tienda?`.

### Component (use `frontend-design` skill — square corners per UI prefs)
- Render as a **segmented radio-button group** (one button per tienda the cliente belongs to AND that has `permitir_login_clientes`).
- Active tienda = `current_user.tienda_activa`.
- Click submits to `POST /clientes/cambiar_tienda_activa` with `tienda_activa_id`.

### New controller action
`app/controllers/clientes/clientes_controller.rb`:
```ruby
def cambiar_tienda_activa
  tienda = Tiendas::Tienda.find(params[:tienda_activa_id])
  unless current_user.puede_loguearse_en?(tienda)
    return head :forbidden
  end
  current_user.update_columns(visualizando_tienda_id: tienda.id, visualizando_local_id: nil)
  # Cross-domain redirect: go to the chosen tienda's domain so the URL host matches.
  redirect_to "https://#{tienda.dominio}/pedidos/new", allow_other_host: true
end
```
Routes: `post 'clientes/cambiar_tienda_activa', to: 'clientes/clientes#cambiar_tienda_activa'`.

> **Cross-domain note:** because tiendas live on different domains, the switcher is essentially "log out of A, jump to B's domain". Sessions are cookie-scoped per host, so the user might need to be logged in there too. Two options:
> 1. **Single-sign-on token** in the redirect URL (signed JWT, one-shot, exchanged for a session) — recommended for UX.
> 2. **Re-prompt for password** on the destination tienda — simpler, ships first.
> Decision: ship option 2 (re-prompt) in v1, design SSO token (option 1) in v2 ticket.

---

## 9. Pedidos index for multi-tienda clientes

### `app/queries/pedidos/pedidos_query.rb` line ~19
```ruby
# OLD
q = q.where(tienda_id: user.tienda_activa)

# NEW
q = if user.cliente? && user.cuenta&.cliente&.multi_tienda?
      q.where(tienda_id: user.tiendas_disponibles.select(:id))
    else
      q.where(tienda_id: user.tienda_activa)
    end
```

### Index view
`app/views/pedidos/_pedidos.html.erb` (or wherever the table is rendered):
- Show a `tienda` column **only** when `current_user.cliente? && current_user.cuenta.cliente.multi_tienda?`.
- Render `pedido.tienda.nombre` (or `iniciales` badge with the tienda's color).

---

## 10. Test plan (RSpec, follow `.github/skills/parallel-testing.md`)

New / updated specs:

| Area | Spec |
|---|---|
| Schema migration round-trip | `spec/migrations/shared_clientes_spec.rb` |
| `Cliente` global uniqueness, `multi_tienda?`, `disponible_en?` | `spec/models/clientes/cliente_spec.rb` |
| `Cuenta` global `nro` | `spec/models/clientes/cuenta_spec.rb` |
| `Usuario#tiendas_disponibles`, `puede_loguearse_en?`, new `tienda_activa` | `spec/models/usuarios/usuario_spec.rb` |
| Tienda `permitir_login_clientes` flag | `spec/models/tiendas/tienda_spec.rb` |
| Login guard (rejects when flag off / cliente not linked) | `spec/requests/sessions_spec.rb` |
| `cambiar_tienda_activa` for cliente users | `spec/requests/clientes/cambiar_tienda_spec.rb` |
| `PedidosQuery` returns multi-tienda pedidos for multi-tienda clientes | `spec/queries/pedidos/pedidos_query_spec.rb` |
| Pedido index shows tienda column when multi | `spec/system/pedidos/index_multi_tienda_spec.rb` |
| Tienda switcher UI on `pedidos/new` | `spec/system/pedidos/new_tienda_switcher_spec.rb` |
| Authorization regressions (admin can't see other tienda's pedidos) | `spec/models/*/authorization_spec.rb` |
| Cuenta-merge rake task | `spec/tasks/clientes_merge_spec.rb` |

Run with `./bin/reset-and-test all` after each migration step.

---

## 11. Rake tasks (one-shot operational helpers)

`lib/tasks/clientes_migration.rake`
```ruby
namespace :clientes_migration do
  desc 'Audit duplicates before migration'
  task audit: :environment do
    # Print same queries used in the audit table above.
  end

  desc 'Merge duplicate clientes by CUIT into the lowest id; re-points cuentas/pedidos/comprobantes/cupones'
  task :merge_duplicates, [:dry_run] => :environment do |_, args|
    dry = args[:dry_run] != 'false'
    # ... merge logic, ensure cliente_tienda links cover both source tiendas
  end

  desc 'Renumber Cuenta.nro globally and seed GeneradorSecuencial'
  task renumber_cuentas: :environment do
    # body shown in § 5
  end

  desc 'Backfill clientes_tiendas from existing clientes.tienda_id'
  task backfill_clientes_tiendas: :environment do
    # body shown in § 4
  end
end
```

---

## 12. Roll-out sequence (smallest safe steps)

1. **Ship** `permitir_login_clientes` column (default true, no behavioural change yet).
2. **Ship** `clientes_tiendas` table + `Cliente has_many :tiendas` + backfill + parallel reads (still keep `clientes.tienda_id` working).
3. **Ship** `Usuario#tiendas_disponibles` & `puede_loguearse_en?` + login guard. Deploy with the flag on for everyone — verify nothing breaks.
4. **Ship** new global `Cuenta.nro` generator + renumber task. Run task in maintenance window.
5. **Ship** authorization rewrites + `PedidosQuery` change. Behind a feature flag (`Rails.application.config.x.shared_clientes`) so it can be toggled.
6. **Ship** client-facing tienda switcher UI + `cambiar_tienda_activa` for clientes + multi-tienda pedidos index column.
7. **Run** cliente-merge rake task in maintenance window. Manually create the cross-tienda `clientes_tiendas` rows for the merged canonical clientes.
8. **Ship** `remove_column :clientes, :tienda_id` migration + drop the now-dead read paths.
9. **Cleanup pass:** drop `usuarios.tienda_cliente_id` if logs confirm it's unused for >2 weeks.

Each step is independently revertible.

---

## 13. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Cross-domain session loss when switching tiendas | v1: re-prompt password; v2: signed SSO handoff token |
| Authorization regression — a client seeing another client's data | Comprehensive `*_authorization_spec.rb` suite + canary in staging |
| AFIP comprobante numbering accidentally globalised | Explicit test that `tienda#{id}_…` scope strings are unchanged |
| Cuenta `nro` re-issue breaks existing comprobante PDFs that print the nro | Comprobantes store `nro` as int already; if they reference cuenta.nro live, snapshot it on the comprobante before renumbering |
| Categoria/Producto catalogue from "wrong" tienda shown after switching | After `cambiar_tienda_activa`, force a full page reload (already done by current admin switcher pattern) |
| Cupon scoped to tienda A used while shopping in tienda B | Already validated at apply-time via `pedido.tienda` — verify with new spec |

---

## 14. Files / line-numbers cheat-sheet (for the implementer)

| File | Touch points |
|---|---|
| [app/models/clientes/cliente.rb](../../app/models/clientes/cliente.rb) | L6 uniqueness, L27 belongs_to, add HABTM `:tiendas`, add `multi_tienda?` |
| [app/models/clientes/cuenta.rb](../../app/models/clientes/cuenta.rb) | L11 add uniqueness, L205 generator scope |
| [app/models/usuarios/usuario.rb](../../app/models/usuarios/usuario.rb) | L26 cuenta belongs_to (no change), L31/L34 tienda associations doc, L47 dni uniqueness, L278-282 `tienda_activa` |
| [app/models/tiendas/tienda.rb](../../app/models/tiendas/tienda.rb) | Add HABTM `:clientes`; add `permitir_login_clientes` accessor / scope |
| [app/models/clientes/authorization.rb](../../app/models/clientes/authorization.rb) | L6 tienda check |
| [app/models/usuarios/authorization.rb](../../app/models/usuarios/authorization.rb) | L6-12 tienda checks |
| [app/queries/pedidos/pedidos_query.rb](../../app/queries/pedidos/pedidos_query.rb) | L19 base scope |
| [app/controllers/shared_controller.rb](../../app/controllers/shared_controller.rb) | L43-45 `buscar_tienda_activa` (mostly OK) |
| [app/controllers/tiendas/tiendas_controller.rb](../../app/controllers/tiendas/tiendas_controller.rb) | L49 `cambiar_tienda_activa` (admin) — used as template |
| `app/controllers/clientes/clientes_controller.rb` | NEW action `cambiar_tienda_activa` |
| `app/controllers/concerns/cliente_login_guard.rb` | NEW |
| [app/views/layouts/_perfil_menu.html.erb](../../app/views/layouts/_perfil_menu.html.erb) | L26-39 admin selector — reuse pattern for client selector partial |
| `app/views/pedidos/_tienda_switcher.html.erb` | NEW (client-facing) |
| [app/views/pedidos/new.html.erb](../../app/views/pedidos/new.html.erb) | Render `_tienda_switcher` at top when multi-tienda |
| [config/routes.rb](../../config/routes.rb) | Add `post 'clientes/cambiar_tienda_activa'` |
| `db/migrate/*_…` | 5 migrations from § 4 |
| `lib/tasks/clientes_migration.rake` | NEW (audit / merge / renumber / backfill) |

---

## 15. Open questions to confirm before coding

1. **Consumidor Final**: keep one shared cliente, or one per tienda (renamed)?  → Recommendation **shared**.
2. **Cuenta nro renumbering**: are existing nros printed on legal documents anywhere? If yes, snapshot them on the comprobante side before renumbering.
3. **Cross-domain login UX**: re-prompt password (simple) vs signed-token SSO (smooth). v1 recommendation: **re-prompt**.
4. **`tienda_cliente_id` on usuario**: keep as "default tienda" forever, or drop after migration? Recommend **keep for now**, drop later.
5. **Categoria visibility for multi-tienda clientes**: when a cliente is linked to tiendas A and B, does it inherit category filters from BOTH? Current model is per-tienda categorias; after the switcher, only the active tienda's categorias apply (✅ likely desired).
6. **Precios**: a precio currently HABTM clientes. After sharing, a precio in tienda A linked to cliente C will only apply when C shops in tienda A (because precios.producto belongs to tienda A). No change needed — confirm with a test.
