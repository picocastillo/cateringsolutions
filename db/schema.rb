# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_05_28_110000) do
  create_table "afectaciones", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "comprobante_id"
    t.integer "afectado_id"
    t.decimal "importe", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["afectado_id"], name: "index_afectaciones_on_afectado_id"
    t.index ["comprobante_id"], name: "index_afectaciones_on_comprobante_id"
    t.index ["created_at"], name: "index_afectaciones_on_created_at"
  end

  create_table "answeres", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "question_id"
    t.string "text"
    t.string "value"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["question_id"], name: "index_answeres_on_question_id"
  end

  create_table "categorias", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "nombre"
    t.integer "codigo"
    t.string "descripcion"
    t.boolean "menu_diario", default: false, null: false
    t.datetime "discontinued_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "tienda_id"
    t.integer "grupo_cocina_id"
    t.boolean "stock_activo", default: false, null: false
    t.boolean "vender_en_carrito", default: false, null: false
    t.index ["codigo"], name: "index_categorias_on_codigo"
    t.index ["discontinued_at"], name: "index_categorias_on_discontinued_at"
    t.index ["nombre"], name: "index_categorias_on_nombre"
    t.index ["tienda_id"], name: "index_categorias_on_tienda_id"
  end

  create_table "clientes", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "nombre"
    t.string "cuit"
    t.string "ciudad"
    t.string "domicilio"
    t.string "email"
    t.string "nro_inscripcion_iibb", limit: 15
    t.string "telefono"
    t.integer "dia_inicio_ciclo_facturacion", default: 1, null: false
    t.integer "vencimiento_a", default: 15, null: false
    t.string "horario_corte_pedidos", default: "00:00", null: false
    t.datetime "discontinued_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "permitir_envios_a_domicilio", default: false
    t.boolean "codigo_externo_en_etiquetas", default: false
    t.boolean "usuario_puede_elegir_cuenta", default: false, null: false
    t.boolean "mostrar_cuentas_corrientes", default: false, null: false
    t.boolean "cuenta_corriente", default: true
    t.boolean "horarios_de_entrega", default: false
    t.boolean "listas_de_precio_privada", default: false, null: false
    t.decimal "limite_compra_pesos", precision: 10, scale: 2
    t.decimal "limite_compra_dolares", precision: 10, scale: 2
    t.index ["cuit"], name: "index_clientes_on_cuit"
    t.index ["discontinued_at"], name: "index_clientes_on_discontinued_at"
    t.index ["horario_corte_pedidos"], name: "index_clientes_on_horario_corte_pedidos"
    t.index ["nombre"], name: "index_clientes_on_nombre"
  end

  create_table "clientes_categorias", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "cliente_id"
    t.integer "categoria_id"
    t.index ["categoria_id"], name: "index_clientes_categorias_on_categoria_id"
    t.index ["cliente_id"], name: "index_clientes_categorias_on_cliente_id"
  end

  create_table "clientes_pedidos_cocina", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "pedido_cocina_id", null: false
    t.bigint "cliente_id", null: false
    t.index ["cliente_id"], name: "index_clientes_pedidos_cocina_on_cliente_id"
    t.index ["pedido_cocina_id"], name: "index_clientes_pedidos_cocina_on_pedido_cocina_id"
  end

  create_table "clientes_precios", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "cliente_id"
    t.integer "precio_id"
    t.index ["cliente_id"], name: "index_clientes_precios_on_cliente_id"
    t.index ["precio_id", "cliente_id"], name: "index_clientes_precios_on_precio_cliente"
    t.index ["precio_id"], name: "index_clientes_precios_on_precio_id"
  end

  create_table "clientes_tiendas", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "cliente_id", null: false
    t.bigint "tienda_id", null: false
    t.index ["cliente_id", "tienda_id"], name: "index_clientes_tiendas_uniq", unique: true
    t.index ["cliente_id"], name: "index_clientes_tiendas_on_cliente_id"
    t.index ["tienda_id", "cliente_id"], name: "index_clientes_tiendas_reverse"
    t.index ["tienda_id"], name: "index_clientes_tiendas_on_tienda_id"
  end

  create_table "clientes_turnos_entrega", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "cliente_id", null: false
    t.bigint "turno_entrega_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["cliente_id", "turno_entrega_id"], name: "index_clientes_turnos_on_cliente_and_turno", unique: true
    t.index ["cliente_id"], name: "index_clientes_turnos_entrega_on_cliente_id"
    t.index ["turno_entrega_id"], name: "index_clientes_turnos_entrega_on_turno_entrega_id"
  end

  create_table "comprobantes", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "type"
    t.bigint "tipo_id"
    t.bigint "pedido_id"
    t.bigint "cuenta_id"
    t.integer "estado_id", default: 1
    t.datetime "fecha_emision", precision: nil
    t.date "fecha_vencimiento"
    t.integer "nro"
    t.decimal "total", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "position"
    t.integer "generado_por_id"
    t.bigint "autor_id"
    t.datetime "contabilizado_el", precision: nil
    t.string "descripcion"
    t.integer "evento_id"
    t.boolean "automatico", default: false, null: false
    t.integer "bonificacion", default: 0, null: false
    t.integer "historial_id"
    t.integer "tienda_id"
    t.integer "local_id"
    t.index ["autor_id"], name: "index_comprobantes_on_autor_id"
    t.index ["contabilizado_el"], name: "index_comprobantes_on_contabilizado_el"
    t.index ["cuenta_id", "estado_id", "fecha_emision"], name: "idx_comprobantes_cuenta_estado_fecha_emision"
    t.index ["cuenta_id"], name: "index_comprobantes_on_cuenta_id"
    t.index ["descripcion"], name: "index_comprobantes_on_descripcion"
    t.index ["estado_id"], name: "index_comprobantes_on_estado_id"
    t.index ["evento_id"], name: "index_comprobantes_on_evento_id"
    t.index ["fecha_emision"], name: "index_comprobantes_on_fecha_emision"
    t.index ["generado_por_id"], name: "index_comprobantes_on_generado_por_id"
    t.index ["historial_id"], name: "index_comprobantes_on_historial_id"
    t.index ["local_id"], name: "index_comprobantes_on_local_id"
    t.index ["nro"], name: "index_comprobantes_on_nro"
    t.index ["pedido_id"], name: "index_comprobantes_on_pedido_id"
    t.index ["tienda_id", "estado_id", "type", "fecha_emision"], name: "idx_comprobantes_tienda_estado_type_fecha_emision"
    t.index ["tienda_id", "local_id", "estado_id", "type", "fecha_emision"], name: "idx_comprobantes_tienda_local_estado_type_fecha"
    t.index ["tienda_id", "tipo_id", "nro"], name: "index_comp_on_tienda_id_tc_nro", unique: true
    t.index ["tienda_id"], name: "index_comprobantes_on_tienda_id"
    t.index ["tipo_id", "nro"], name: "index_comprobantes_on_tc_nro"
    t.index ["tipo_id"], name: "index_comprobantes_on_tipo_id"
    t.index ["type"], name: "index_comprobantes_on_type"
    t.index ["updated_at"], name: "index_comprobantes_on_updated_at"
  end

  create_table "comprobantes_asociados", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "comprobante_id"
    t.integer "asociado_id"
    t.index ["asociado_id"], name: "index_comprobantes_asociados_on_asociado_id"
    t.index ["comprobante_id"], name: "index_comprobantes_asociados_on_comprobante_id"
  end

  create_table "configuraciones_impositivas", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "type"
    t.integer "cliente_id"
    t.integer "impuesto_id"
    t.integer "condicion_id"
    t.index ["cliente_id"], name: "index_configuraciones_impositivas_on_cliente_id"
    t.index ["condicion_id"], name: "index_configuraciones_impositivas_on_condicion_id"
    t.index ["impuesto_id"], name: "index_configuraciones_impositivas_on_impuesto_id"
    t.index ["type"], name: "index_configuraciones_impositivas_on_type"
  end

  create_table "cotizaciones_dolar", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.date "fecha", null: false
    t.decimal "precio_venta", precision: 10, scale: 2, null: false
    t.decimal "precio_compra", precision: 10, scale: 2
    t.string "fuente", default: "oficial", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fecha"], name: "index_cotizaciones_dolar_on_fecha", unique: true
  end

  create_table "cuentas", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "nro"
    t.string "nombre"
    t.integer "position"
    t.bigint "cliente_id"
    t.datetime "discontinued_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "cuenta_corriente_parcial"
    t.string "horario_corte_pedidos"
    t.index ["cliente_id"], name: "index_cuentas_on_cliente_id"
    t.index ["horario_corte_pedidos"], name: "index_cuentas_on_horario_corte_pedidos"
    t.index ["nombre"], name: "index_cuentas_clientes_on_nombre"
    t.index ["nro"], name: "index_cuentas_on_nro_unique", unique: true
    t.index ["position"], name: "index_cuentas_clientes_on_position"
  end

  create_table "cuentas_pedidos_cocina", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "pedido_cocina_id", null: false
    t.bigint "cuenta_id", null: false
    t.index ["cuenta_id"], name: "index_cuentas_pedidos_cocina_on_cuenta_id"
    t.index ["pedido_cocina_id"], name: "index_cuentas_pedidos_cocina_on_pedido_cocina_id"
  end

  create_table "cupones", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "codigo", null: false
    t.bigint "tienda_id"
    t.string "tipo_descuento", default: "importe", null: false
    t.decimal "importe", precision: 10, scale: 2
    t.decimal "porcentaje", precision: 5, scale: 2
    t.decimal "limite_bonificacion", precision: 10, scale: 2
    t.date "fecha_vencimiento"
    t.boolean "utilizado", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "grupo"
    t.boolean "cancelado", default: false, null: false
    t.string "nombre"
    t.index ["cancelado"], name: "index_cupones_on_cancelado"
    t.index ["codigo"], name: "index_cupones_on_codigo", unique: true
    t.index ["fecha_vencimiento"], name: "index_cupones_on_fecha_vencimiento"
    t.index ["grupo"], name: "index_cupones_on_grupo"
    t.index ["tienda_id"], name: "index_cupones_on_tienda_id"
    t.index ["utilizado"], name: "index_cupones_on_utilizado"
  end

  create_table "delayed_jobs", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at", precision: nil
    t.datetime "locked_at", precision: nil
    t.datetime "failed_at", precision: nil
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "descuentos_venta_mostrador", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "tienda_id", null: false
    t.string "nombre", null: false
    t.string "tipo_descuento", default: "porcentaje", null: false
    t.decimal "porcentaje", precision: 5, scale: 2
    t.decimal "importe", precision: 12, scale: 2
    t.decimal "limite_bonificacion", precision: 12, scale: 2
    t.string "medio_pago_tipo", default: "", null: false
    t.decimal "importe_minimo", precision: 12, scale: 2, default: "0.0", null: false
    t.boolean "activo", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activo"], name: "index_descuentos_venta_mostrador_on_activo"
    t.index ["medio_pago_tipo"], name: "index_descuentos_venta_mostrador_on_medio_pago_tipo"
    t.index ["tienda_id"], name: "index_descuentos_venta_mostrador_on_tienda_id"
  end

  create_table "descuentos_venta_mostrador_clientes", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "descuento_venta_mostrador_id", null: false
    t.bigint "cliente_id", null: false
    t.index ["cliente_id"], name: "idx_descuentos_vm_cliente_id"
    t.index ["descuento_venta_mostrador_id", "cliente_id"], name: "idx_descuentos_vm_clientes_unique", unique: true
  end

  create_table "documentos", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "documentable_id"
    t.string "documentable_type"
    t.string "documento_file_name"
    t.string "documento_content_type"
    t.integer "documento_file_size"
    t.datetime "documento_updated_at", precision: nil
    t.integer "position"
    t.integer "autor_id"
    t.string "observaciones"
    t.index ["autor_id"], name: "index_imagenes_on_autor_id"
    t.index ["documentable_id", "documentable_type"], name: "index_documentos_on_documentable_id_and_documentable_type"
    t.index ["documentable_type"], name: "index_documentos_on_migrado_and_imagen_id_and_documentable_type"
    t.index ["position"], name: "index_documentos_on_position"
  end

  create_table "etiquetas_notificables", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "etiquetado_id"
    t.string "etiquetado_type"
    t.integer "etiquetador_id"
    t.string "etiquetador_type"
    t.string "nombre"
    t.index ["etiquetado_id", "etiquetado_type"], name: "index_etiquetas_notificables_on_etiquetado"
    t.index ["etiquetado_type"], name: "index_etiquetas_notificables_on_etiquetado_type"
    t.index ["etiquetador_id", "etiquetador_type"], name: "index_etiquetas_notificables_on_etiquetable"
    t.index ["etiquetador_type"], name: "index_etiquetas_notificables_on_etiquetador_type"
  end

  create_table "eventos", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "type"
    t.integer "usuario_id"
    t.string "origen_type"
    t.integer "origen_id"
    t.datetime "fecha", precision: nil, null: false
    t.integer "position"
    t.integer "estado_generado_id"
    t.text "mensajes"
    t.string "interface"
    t.string "nro_lote"
    t.string "codigo_sobre_proveedor"
    t.boolean "exitoso", default: false, null: false
    t.integer "historial_id"
    t.index ["estado_generado_id"], name: "index_eventos_on_estado_generado_id"
    t.index ["fecha"], name: "index_eventos_on_fecha"
    t.index ["historial_id"], name: "index_eventos_on_historial_id"
    t.index ["origen_type", "origen_id"], name: "index_eventos_on_origen_type_and_origen_id"
    t.index ["position"], name: "index_eventos_on_position"
    t.index ["type"], name: "index_eventos_on_type"
    t.index ["usuario_id"], name: "index_eventos_on_usuario_id"
  end

  create_table "favoritos", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "usuario_id"
    t.bigint "producto_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["producto_id"], name: "index_favoritos_on_producto_id"
    t.index ["usuario_id", "producto_id", "updated_at"], name: "index_favoritos_on_usuario_id_and_producto_id_and_updated_at"
    t.index ["usuario_id"], name: "index_favoritos_on_usuario_id"
  end

  create_table "feriados", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "calendario_id"
    t.date "fecha"
    t.string "descripcion"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["calendario_id"], name: "index_feriados_on_calendario_id"
    t.index ["fecha"], name: "index_feriados_on_fecha"
  end

  create_table "generadores_secuenciales", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "scope", limit: 50
    t.string "type", limit: 50
    t.integer "ultimo", default: 0, null: false
    t.index ["scope", "ultimo"], name: "index_generadores_secuenciales_unique", unique: true
  end

  create_table "grupos", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "nombre"
    t.string "descripcion"
    t.datetime "discontinued_at", precision: nil
    t.index ["discontinued_at"], name: "index_grupos_on_discontinued_at"
  end

  create_table "grupos_cocinas", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "nombre"
    t.integer "codigo"
    t.string "descripcion"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "tienda_id"
    t.index ["codigo"], name: "index_categorias_on_codigo"
    t.index ["nombre"], name: "index_categorias_on_nombre"
    t.index ["tienda_id"], name: "index_categorias_on_tienda_id"
  end

  create_table "historiales", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
  end

  create_table "horarios", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "position"
    t.integer "tienda_id"
    t.string "horario"
    t.string "nombre"
    t.boolean "predeterminado", default: false, null: false
    t.datetime "discontinued_at", precision: nil
    t.index ["discontinued_at"], name: "index_horarios_on_discontinued_at"
    t.index ["position"], name: "index_horarios_on_position"
    t.index ["tienda_id"], name: "index_horarios_on_tienda_id"
  end

  create_table "imagenes", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "imaginable_id"
    t.string "imaginable_type"
    t.string "imagen_file_name"
    t.string "imagen_content_type"
    t.integer "imagen_file_size"
    t.datetime "imagen_updated_at", precision: nil
    t.integer "position"
    t.string "pie"
  end

  create_table "locales", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "nombre"
    t.string "domicilio"
    t.string "telefono"
    t.integer "tienda_id"
    t.index ["nombre"], name: "index_locales_on_nombre"
    t.index ["tienda_id"], name: "index_locales_on_tienda_id"
  end

  create_table "medios_pago", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "type"
    t.integer "flujo_economico_id"
    t.boolean "propio", default: true, null: false
    t.integer "tipo_id"
    t.integer "nro"
    t.decimal "importe", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "cuenta_id"
    t.integer "sucursal"
    t.integer "cp"
    t.date "fecha_emision"
    t.date "fecha_presentacion"
    t.date "fecha_acreditacion"
    t.string "cuit"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "cuenta_bancaria_id"
    t.date "fecha_retencion"
    t.integer "pago_electronico_id"
    t.index ["cuenta_bancaria_id"], name: "index_medios_pago_on_cuenta_bancaria_id"
    t.index ["cuenta_id"], name: "index_medios_pago_on_cuenta_id"
    t.index ["fecha_acreditacion"], name: "index_medios_pago_on_fecha_acreditacion"
    t.index ["fecha_emision"], name: "index_medios_pago_on_fecha_emision"
    t.index ["fecha_presentacion"], name: "index_medios_pago_on_fecha_presentacion"
    t.index ["flujo_economico_id"], name: "index_medios_pago_on_flujo_economico_id"
    t.index ["nro"], name: "index_medios_pago_on_nro"
    t.index ["pago_electronico_id"], name: "index_medios_pago_on_pago_electronico_id"
    t.index ["type"], name: "index_medios_pago_on_type"
  end

  create_table "mensajes", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "autor_id"
    t.string "asunto"
    t.boolean "admite_comentarios", default: true
    t.text "cuerpo"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.datetime "recordar_el", precision: nil
    t.string "recordar_a", default: "a_mi"
    t.integer "duracion", default: 2
    t.integer "mensaje_id"
    t.integer "respuesta_de_id"
    t.boolean "mostrar_destinatarios", default: true, null: false
    t.integer "version_logica", default: 3, null: false
    t.index ["asunto", "cuerpo"], name: "full", type: :fulltext
    t.index ["asunto"], name: "index_mensajes_on_asunto"
    t.index ["autor_id"], name: "index_mensajes_on_autor_id"
    t.index ["created_at", "mensaje_id"], name: "index_mensajes_on_created_at_mensaje_id"
    t.index ["mensaje_id"], name: "index_mensajes_on_mensaje_id"
    t.index ["respuesta_de_id"], name: "index_mensajes_on_respuesta_de_id"
    t.index ["updated_at"], name: "index_mensajes_on_updated_at"
  end

  create_table "menus_diarios", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "autor_id"
    t.date "fecha"
    t.string "descripcion"
    t.integer "position"
    t.text "observaciones"
    t.datetime "discontinued_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "tienda_id"
    t.integer "tipo_id", default: 1, null: false
    t.index ["autor_id"], name: "index_menus_diarios_on_autor_id"
    t.index ["discontinued_at"], name: "index_horarios_laborales_on_discontinued_at"
    t.index ["position"], name: "index_horarios_laborales_on_position"
    t.index ["tienda_id", "fecha", "tipo_id"], name: "idx_menus_diarios_tienda_fecha_tipo"
    t.index ["tienda_id"], name: "index_menus_diarios_on_tienda_id"
  end

  create_table "menus_diarios_productos", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "menu_diario_id"
    t.integer "producto_id"
    t.index ["menu_diario_id"], name: "index_menus_diarios_productos_on_menu_diario_id"
    t.index ["producto_id"], name: "index_menus_diarios_productos_on_producto_id"
  end

  create_table "metricas_errors", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.datetime "fecha", precision: nil, null: false
    t.string "error_class"
    t.text "error_message"
    t.string "controller_action"
    t.integer "status_code"
    t.string "ip"
    t.string "url"
    t.datetime "created_at", precision: nil, null: false
    t.index ["error_class"], name: "index_metricas_errors_on_error_class"
    t.index ["fecha"], name: "index_metricas_errors_on_fecha"
  end

  create_table "metricas_snapshots", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.date "fecha", null: false
    t.integer "tienda_id"
    t.integer "total_requests", default: 0
    t.integer "requests_mobile", default: 0
    t.integer "requests_desktop", default: 0
    t.integer "requests_unknown", default: 0
    t.decimal "avg_response_time_ms", precision: 8, scale: 2, default: "0.0"
    t.decimal "p95_response_time_ms", precision: 8, scale: 2, default: "0.0"
    t.decimal "max_response_time_ms", precision: 8, scale: 2, default: "0.0"
    t.integer "status_2xx", default: 0
    t.integer "status_3xx", default: 0
    t.integer "status_4xx", default: 0
    t.integer "status_5xx", default: 0
    t.integer "unique_ips", default: 0
    t.text "top_endpoints"
    t.text "top_ips"
    t.text "response_times_histogram"
    t.text "worst_response_times"
    t.text "delayed_jobs_stats"
    t.text "requests_by_hour"
    t.decimal "db_total_size_mb", precision: 10, scale: 2, default: "0.0"
    t.text "db_table_sizes"
    t.integer "db_active_connections", default: 0
    t.integer "db_max_connections", default: 0
    t.text "db_slow_queries"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["fecha", "tienda_id"], name: "idx_metricas_fecha_tienda", unique: true
    t.index ["tienda_id"], name: "index_metricas_snapshots_on_tienda_id"
  end

  create_table "movimientos_cbles", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "cuenta_id"
    t.integer "comprobante_id"
    t.integer "imputado_id"
    t.integer "afectacion_id"
    t.decimal "importe", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "saldo", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", precision: nil
    t.integer "indice"
    t.integer "tienda_id"
    t.index ["afectacion_id"], name: "index_movimientos_on_afectacion_id"
    t.index ["comprobante_id"], name: "index_movimientos_on_comprobante_id"
    t.index ["cuenta_id"], name: "index_movimientos_on_cuenta_id"
    t.index ["imputado_id"], name: "index_movimientos_on_imputado_id"
    t.index ["indice"], name: "index_movimientos_cbles_on_indice"
    t.index ["saldo"], name: "index_movimientos_cbles_on_saldo"
    t.index ["tienda_id", "cuenta_id", "indice"], name: "idx_movimientos_tienda_cuenta_indice"
    t.index ["tienda_id"], name: "index_movimientos_cbles_on_tienda_id"
  end

  create_table "notificaciones", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "type"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "notificaciones_enviadas", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "notificacion_id"
    t.integer "destinatario_id"
    t.integer "remitente_id"
    t.integer "via_id", default: 1, null: false
    t.integer "mensaje_id"
    t.datetime "leida_el", precision: nil
    t.boolean "favorita", default: false, null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "ultima", default: false, null: false
    t.integer "sin_leer_en_cadena", default: 0, null: false
    t.index ["destinatario_id", "mensaje_id", "via_id"], name: "index_notificaciones_enviadas_mensaje_favorito"
    t.index ["destinatario_id", "via_id", "favorita"], name: "index_notificaciones_enviadas_query_panel_favoritos"
    t.index ["destinatario_id", "via_id", "leida_el"], name: "index_notificaciones_enviadas_query_panel_no_leidos"
    t.index ["destinatario_id", "via_id", "ultima", "created_at"], name: "index_notificaciones_enviadas_query_panel_main"
    t.index ["mensaje_id"], name: "index_notificaciones_enviadas_on_mensaje_id"
    t.index ["notificacion_id", "destinatario_id", "via_id"], name: "index_notificaciones_enviadas_unique", unique: true
    t.index ["remitente_id"], name: "index_notificaciones_enviadas_on_remitente_id"
  end

  create_table "pagos_electronicos", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "pedido_id"
    t.integer "position"
    t.bigint "pago_id"
    t.datetime "date_created", precision: nil
    t.datetime "date_approved", precision: nil
    t.datetime "date_last_updated", precision: nil
    t.datetime "money_release_date", precision: nil
    t.string "payment_method_id"
    t.string "payment_type_id"
    t.string "status"
    t.string "status_detail"
    t.string "currency_id"
    t.string "description"
    t.bigint "collector_id"
    t.bigint "order_id"
    t.integer "installments", default: 1, null: false
    t.decimal "transaction_amount", precision: 12, scale: 2
    t.decimal "transaction_amount_refunded", precision: 12, scale: 2
    t.decimal "coupon_amount", precision: 12, scale: 2
    t.decimal "net_received_amount", precision: 12, scale: 2
    t.decimal "total_paid_amount", precision: 12, scale: 2
    t.decimal "overpaid_amount", precision: 12, scale: 2
    t.decimal "installment_amount", precision: 12, scale: 2
    t.bigint "pedido_multiple_id"
    t.index ["pago_id"], name: "index_pagos_electronicos_on_pago_id"
    t.index ["pedido_id"], name: "index_pagos_electronicos_on_pedido_id"
    t.index ["pedido_multiple_id"], name: "index_pagos_electronicos_on_pedido_multiple_id"
    t.index ["position"], name: "index_pagos_electronicos_on_position"
  end

  create_table "pedidos", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "autor_id"
    t.bigint "usuario_id"
    t.date "fecha"
    t.integer "codigo"
    t.string "viendo_categorias_csv"
    t.string "busqueda"
    t.integer "estado_id", default: 1
    t.string "observaciones_cliente"
    t.string "observaciones_chef"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "facturado", default: false
    t.boolean "envio_a_domicilio", default: false
    t.string "direccion_envio"
    t.integer "cuenta_id"
    t.boolean "pedido_para_empresa", default: false
    t.string "para"
    t.integer "tienda_id"
    t.boolean "venta_mostrador", default: false
    t.string "confirmation_token", limit: 26
    t.boolean "cobrado", default: false
    t.integer "horario_id"
    t.decimal "costo_envio_domicilio", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "local_id"
    t.integer "pedido_cocina_id"
    t.boolean "stock_reducido", default: false, null: false
    t.bigint "turno_entrega_id"
    t.bigint "cupon_id"
    t.string "medio_pago_tipo"
    t.datetime "aceptado_el"
    t.integer "aceptado_por_id"
    t.bigint "descuento_venta_mostrador_id"
    t.decimal "monto_descuento_vm", precision: 12, scale: 2
    t.bigint "pedido_multiple_id"
    t.index ["autor_id"], name: "index_pedidos_on_autor_id"
    t.index ["confirmation_token"], name: "index_pedidos_on_confirmation_token"
    t.index ["cuenta_id", "estado_id", "fecha"], name: "index_pedidos_on_cuenta_estado_fecha"
    t.index ["cuenta_id", "para"], name: "index_pedidos_on_cuenta_para"
    t.index ["cupon_id"], name: "index_pedidos_on_cupon_id"
    t.index ["descuento_venta_mostrador_id"], name: "index_pedidos_on_descuento_venta_mostrador_id"
    t.index ["estado_id"], name: "index_pedidos_on_estado_id"
    t.index ["horario_id"], name: "index_pedidos_on_horario_id"
    t.index ["local_id"], name: "index_pedidos_on_local_id"
    t.index ["pedido_cocina_id"], name: "index_pedidos_on_pedido_cocina_id"
    t.index ["pedido_multiple_id"], name: "index_pedidos_on_pedido_multiple_id"
    t.index ["stock_reducido"], name: "index_pedidos_on_stock_reducido"
    t.index ["tienda_id", "cuenta_id", "fecha", "codigo"], name: "idx_pedidos_tienda_cuenta_fecha_codigo"
    t.index ["tienda_id", "estado_id", "fecha", "codigo"], name: "idx_pedidos_tienda_estado_fecha_codigo"
    t.index ["tienda_id", "fecha", "codigo"], name: "idx_pedidos_tienda_fecha_codigo"
    t.index ["tienda_id", "local_id", "estado_id", "fecha"], name: "idx_pedidos_tienda_local_estado_fecha"
    t.index ["tienda_id", "updated_at"], name: "index_pedidos_on_tienda_updated_at"
    t.index ["tienda_id", "venta_mostrador", "estado_id", "autor_id"], name: "index_pedidos_on_mostrador_lookup"
    t.index ["tienda_id", "venta_mostrador", "fecha", "codigo"], name: "idx_pedidos_tienda_vm_fecha_codigo"
    t.index ["turno_entrega_id"], name: "index_pedidos_on_turno_entrega_id"
    t.index ["usuario_id", "fecha", "codigo"], name: "index_pedidos_on_usuario_id_fecha_and_codigo"
    t.index ["usuario_id"], name: "index_pedidos_on_usuario_id"
  end

  create_table "pedidos_cocina", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.datetime "fecha", precision: nil
    t.string "descripcion"
    t.integer "autor_id"
    t.integer "codigo"
    t.integer "tienda_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["autor_id"], name: "index_pedidos_cocina_on_autor_id"
    t.index ["codigo"], name: "index_pedidos_cocina_on_codigo"
    t.index ["fecha"], name: "index_pedidos_cocina_on_fecha"
    t.index ["tienda_id", "fecha", "updated_at"], name: "associated_index"
    t.index ["tienda_id"], name: "index_pedidos_cocina_on_tienda_id"
  end

  create_table "pedidos_cocina_usuarios", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "pedido_cocina_id", null: false
    t.bigint "usuario_id", null: false
    t.index ["pedido_cocina_id"], name: "index_pedidos_cocina_usuarios_on_pedido_cocina_id"
    t.index ["usuario_id"], name: "index_pedidos_cocina_usuarios_on_usuario_id"
  end

  create_table "pedidos_medios_pago", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "pedido_id", null: false
    t.string "tipo", null: false
    t.decimal "importe", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pedido_id"], name: "index_pedidos_medios_pago_on_pedido_id"
  end

  create_table "pedidos_multiples", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "usuario_id"
    t.integer "estado", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "cuenta_id"
    t.index ["cuenta_id"], name: "index_pedidos_multiples_on_cuenta_id"
    t.index ["usuario_id"], name: "index_pedidos_multiples_on_usuario_id"
  end

  create_table "pedidos_productos_solicitados", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "pedido_id"
    t.integer "producto_solicitado_id"
    t.index ["pedido_id", "producto_solicitado_id"], name: "i_trat_tur_on_pedido_id_and_producto_solicitado_id"
  end

  create_table "plantillas", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "nombre"
    t.string "clase_cbte"
    t.index ["clase_cbte"], name: "index_plantillas_on_clase_cbte"
  end

  create_table "precios", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "producto_id"
    t.date "fecha_desde"
    t.date "fecha_hasta"
    t.integer "position"
    t.decimal "importe", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "discontinued_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["discontinued_at"], name: "index_horarios_laborales_on_discontinued_at"
    t.index ["fecha_desde", "fecha_hasta", "producto_id"], name: "index_precios_on_fechas_producto"
    t.index ["producto_id", "fecha_desde", "fecha_hasta"], name: "index_precios_on_producto_fechas"
    t.index ["producto_id", "position"], name: "precios_on_position"
    t.index ["producto_id"], name: "index_precios_on_producto_id"
  end

  create_table "preferencias", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "nombre"
    t.boolean "estado", default: false
    t.string "valor"
    t.bigint "usuario_id"
    t.index ["usuario_id", "nombre"], name: "index_preferencias_on_usuario_id_and_nombre", unique: true
    t.index ["usuario_id"], name: "index_preferencias_on_usuario_id"
  end

  create_table "procesos", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "type"
    t.date "desde"
    t.date "hasta"
    t.text "params"
    t.datetime "run_at", precision: nil
    t.integer "autor_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "adjunto_file_name"
    t.string "adjunto_content_type"
    t.string "adjunto_file_size"
    t.boolean "importar", default: false, null: false
    t.integer "generado_por_id"
    t.integer "tienda_id"
    t.index ["autor_id"], name: "index_procesos_on_autor_id"
    t.index ["tienda_id", "autor_id"], name: "index_procesos_on_tienda_id_autor_id"
  end

  create_table "productos", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "categoria_id"
    t.string "nombre"
    t.string "codigo"
    t.string "descripcion"
    t.string "color"
    t.datetime "discontinued_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "codigos_externos"
    t.integer "tienda_id"
    t.date "mostrar_como_nuevo_hasta"
    t.boolean "pesable", default: false, null: false
    t.index ["categoria_id", "nombre"], name: "index_productos_on_categoria_id_and_nombre"
    t.index ["categoria_id"], name: "index_productos_on_categoria_id"
    t.index ["codigo"], name: "index_productos_on_nombre"
    t.index ["discontinued_at"], name: "index_productos_on_discontinued_at"
    t.index ["nombre"], name: "index_productos_on_codigo"
    t.index ["tienda_id", "codigos_externos"], name: "index_productos_on_tienda_codigos_externos"
    t.index ["tienda_id", "discontinued_at", "pesable", "categoria_id"], name: "index_productos_on_tienda_discontinued_pesable_categoria"
    t.index ["tienda_id"], name: "index_productos_on_tienda_id"
  end

  create_table "productos_solicitados", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "pedido_id"
    t.bigint "producto_id"
    t.integer "cantidad", default: 0, null: false
    t.decimal "precio_unitario", precision: 12, scale: 2, default: "0.0", null: false
    t.text "observaciones_cliente"
    t.text "observaciones_chef"
    t.boolean "realizado", default: false, null: false
    t.integer "menu_diario_id"
    t.boolean "pesable", default: false
    t.decimal "precio_con_descuento", precision: 12, scale: 2
    t.decimal "peso", precision: 10, scale: 3
    t.virtual "menu_diario_id_norm", type: :integer, as: "coalesce(`menu_diario_id`,0)", stored: true
    t.index ["menu_diario_id"], name: "index_productos_solicitados_on_menu_diario_id"
    t.index ["pedido_id", "menu_diario_id", "producto_id"], name: "idx_prod_solicitados_pedido_menu_producto"
    t.index ["pedido_id", "producto_id", "menu_diario_id_norm"], name: "index_productos_solicitados_unique_per_pedido", unique: true
    t.index ["pedido_id", "producto_id"], name: "index_prod_solicitados_on_pedido_producto"
    t.index ["pedido_id"], name: "index_productos_solicitados_on_pedido_id"
    t.index ["producto_id"], name: "index_productos_solicitados_on_producto_id"
  end

  create_table "productos_stock_movimientos", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "stock_id", null: false
    t.bigint "usuario_id"
    t.string "tipo", null: false
    t.integer "cantidad", null: false
    t.integer "cantidad_anterior", null: false
    t.integer "cantidad_nueva", null: false
    t.text "motivo"
    t.text "observaciones"
    t.datetime "fecha", precision: nil, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["fecha"], name: "index_stock_movimientos_fecha"
    t.index ["stock_id", "fecha"], name: "index_stock_movimientos_stock_fecha"
    t.index ["stock_id"], name: "index_productos_stock_movimientos_on_stock_id"
    t.index ["stock_id"], name: "index_stock_movimientos_stock"
    t.index ["tipo", "fecha"], name: "index_stock_movimientos_tipo_fecha"
    t.index ["tipo"], name: "index_stock_movimientos_tipo"
    t.index ["usuario_id"], name: "index_productos_stock_movimientos_on_usuario_id"
  end

  create_table "productos_stocks", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "producto_id", null: false
    t.bigint "tienda_id", null: false
    t.bigint "local_id"
    t.integer "cantidad_actual", default: 0, null: false
    t.integer "cantidad_minima", default: 0, null: false
    t.integer "cantidad_maxima"
    t.text "observaciones"
    t.boolean "activo", default: true, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["cantidad_actual", "cantidad_minima"], name: "index_stocks_cantidad_comparison"
    t.index ["cantidad_actual"], name: "index_stocks_cantidad_actual"
    t.index ["local_id"], name: "index_productos_stocks_on_local_id"
    t.index ["producto_id", "tienda_id", "local_id"], name: "index_stocks_producto_tienda_local", unique: true
    t.index ["producto_id"], name: "index_productos_stocks_on_producto_id"
    t.index ["tienda_id", "local_id"], name: "index_stocks_tienda_local"
    t.index ["tienda_id"], name: "index_productos_stocks_on_tienda_id"
  end

  create_table "progresos", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "progresable_id"
    t.string "progresable_type"
    t.integer "actual", default: 0, null: false
    t.integer "total", default: 0, null: false
    t.datetime "fecha_inicio", precision: nil
    t.datetime "fecha_fin", precision: nil
    t.text "errores"
    t.boolean "cancelado", default: false, null: false
  end

  create_table "provincias", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "codigo"
    t.string "nombre", limit: 20
    t.string "letra", limit: 1
  end

  create_table "questiones", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "survey_id"
    t.text "text"
    t.string "question_type"
    t.boolean "required"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["survey_id"], name: "index_questiones_on_survey_id"
  end

  create_table "questiones_responses", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "survey_response_id"
    t.bigint "question_id"
    t.bigint "answer_id"
    t.text "response_text"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["answer_id"], name: "index_questiones_responses_on_answer_id"
    t.index ["question_id"], name: "index_questiones_responses_on_question_id"
    t.index ["survey_response_id"], name: "index_questiones_responses_on_survey_response_id"
  end

  create_table "recordatorios", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "mensaje_id"
    t.integer "destinatario_id"
    t.integer "autor_id"
    t.datetime "created_at", precision: nil
    t.datetime "recordar_el", precision: nil
    t.integer "duracion", default: 2, null: false
    t.index ["recordar_el"], name: "index_recordatorios_on_recordar_el"
  end

  create_table "registration_tokens", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.bigint "usuario_id"
    t.string "token"
    t.string "platform", limit: 20
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["token"], name: "index_registration_tokens_on_token", unique: true
    t.index ["usuario_id", "token"], name: "index_registration_tokens_on_usuario_id_and_token"
  end

  create_table "renglones", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "comprobante_id"
    t.integer "tasa_iva_id", default: 1, null: false
    t.bigint "producto_id"
    t.string "descripcion", limit: 500
    t.integer "cantidad", default: 1, null: false
    t.decimal "precio_unitario", precision: 12, scale: 2, default: "0.0", null: false
    t.bigint "comprobante_afectado_id"
    t.bigint "categoria_id"
    t.decimal "peso", precision: 10, scale: 3
    t.index ["categoria_id"], name: "index_renglones_on_categoria_id"
    t.index ["comprobante_afectado_id"], name: "index_renglones_on_comprobante_afectado_id"
    t.index ["comprobante_id", "producto_id"], name: "index_renglones_unique_per_comprobante_producto", unique: true
    t.index ["comprobante_id"], name: "index_renglones_on_comprobante_id"
    t.index ["producto_id"], name: "index_renglones_on_producto_id"
  end

  create_table "roles", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "nombre"
    t.string "titulo"
    t.string "modulo"
    t.boolean "sugerido", default: false, null: false
    t.text "transitivos"
    t.text "descripcion"
    t.index ["modulo"], name: "index_roles_on_modulo"
  end

  create_table "roles_asignados", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "usuario_id", null: false
    t.integer "rol_id", null: false
    t.index ["usuario_id", "rol_id"], name: "index_roles_asignados_on_usuario_id_and_rol_id", unique: true
  end

  create_table "sessions", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.integer "user_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subtotales", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "comprobante_id"
    t.integer "tasa_iva_id"
    t.decimal "base_imponible", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "iva", precision: 12, scale: 2, default: "0.0", null: false
    t.index ["comprobante_id", "tasa_iva_id"], name: "index_subtotales_on_comprobante_id_and_tasa_iva_id", unique: true
    t.index ["comprobante_id"], name: "index_subtotales_on_comprobante_id"
  end

  create_table "survey_responses", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "survey_id"
    t.bigint "user_id"
    t.bigint "tienda_id", null: false
    t.datetime "completed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["survey_id"], name: "index_survey_responses_on_survey_id"
    t.index ["tienda_id"], name: "index_survey_responses_on_tienda_id"
    t.index ["user_id"], name: "index_survey_responses_on_user_id"
  end

  create_table "surveys", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.boolean "active"
    t.bigint "tienda_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.date "fecha_desde"
    t.date "fecha_hasta"
    t.index ["tienda_id"], name: "index_surveys_on_tienda_id"
  end

  create_table "suscripciones", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "usuario_id"
    t.integer "tipo_id"
    t.string "vias_ids"
    t.index ["tipo_id"], name: "index_suscripciones_on_tipo_id"
    t.index ["usuario_id", "tipo_id"], name: "index_suscripciones_on_usuario_id_and_tipo_id", unique: true
  end

  create_table "taggings", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "tag_id"
    t.integer "taggable_id"
    t.integer "tagger_id"
    t.string "tagger_type"
    t.string "taggable_type"
    t.string "context"
    t.datetime "created_at", precision: nil
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context"
  end

  create_table "tags", id: :integer, charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "taggings_count", default: 0
  end

  create_table "tiendas", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "nombre"
    t.string "descripcion"
    t.string "color_de_fondo"
    t.string "color_de_menu"
    t.string "color_barra_superior"
    t.string "color_fondo_logo"
    t.string "color_barra_filtros"
    t.string "color_links_hover"
    t.string "color_links"
    t.string "color_titulo"
    t.string "dominio"
    t.string "email"
    t.string "telefono"
    t.string "domicilio"
    t.string "video_ayuda"
    t.datetime "discontinued_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "venta_mostrador", default: false
    t.boolean "carrito_de_compras", default: false
    t.boolean "despachos", default: false
    t.text "mensaje_bienvenida"
    t.string "mensaje_ingreso_a_carrito"
    t.boolean "horarios_de_entrega", default: false
    t.decimal "costo_envio_domicilio", precision: 12, scale: 2, default: "0.0", null: false
    t.boolean "multiple_locales", default: false
    t.boolean "impresion_productos", default: false
    t.string "stock_notifications_email"
    t.boolean "maneja_stock", default: false, null: false
    t.boolean "dark_mode_login", default: false, null: false
    t.boolean "productos_pesables", default: false, null: false
    t.bigint "local_atencion_carrito_id"
    t.boolean "soporta_productos_diarios", default: false, null: false
    t.boolean "muestra_mas_productos", default: false, null: false
    t.boolean "muestra_menus_del_dia", default: false, null: false
    t.boolean "permitir_login_clientes", default: true, null: false
    t.boolean "muestra_mas_productos_por_categoria", default: false, null: false
    t.index ["discontinued_at"], name: "index_tiendas_on_discontinued_at"
    t.index ["dominio"], name: "index_tiendas_on_dominio"
    t.index ["local_atencion_carrito_id"], name: "index_tiendas_on_local_atencion_carrito_id"
  end

  create_table "tipos_comprobantes", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "desc"
    t.string "clase", limit: 50
    t.string "letra", limit: 1
    t.integer "codigo"
    t.boolean "debitan", default: true, null: false
    t.index ["codigo"], name: "index_tipos_comprobantes_on_codigo"
    t.index ["letra", "clase"], name: "index_tipos_comprobantes_on_letra_and_clase"
  end

  create_table "turnos_entrega", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "codigo", null: false
    t.time "hora_corte", null: false
    t.text "descripcion"
    t.boolean "activo", default: true, null: false
    t.integer "posicion", default: 0, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["activo"], name: "index_turnos_entrega_on_activo"
    t.index ["codigo"], name: "index_turnos_entrega_on_codigo", unique: true
  end

  create_table "turnos_entrega_categorias", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.bigint "turno_entrega_id", null: false
    t.bigint "categoria_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["categoria_id"], name: "index_turnos_entrega_categorias_on_categoria_id"
    t.index ["turno_entrega_id", "categoria_id"], name: "index_turnos_categorias_on_turno_and_categoria", unique: true
    t.index ["turno_entrega_id"], name: "index_turnos_entrega_categorias_on_turno_entrega_id"
  end

  create_table "usuarios", charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.string "login"
    t.string "crypted_password", limit: 40
    t.string "salt", limit: 40
    t.datetime "created_at", precision: nil
    t.bigint "cuenta_id"
    t.datetime "updated_at", precision: nil
    t.string "remember_token"
    t.datetime "remember_token_expires_at", precision: nil
    t.string "nombre"
    t.string "telefono"
    t.string "email"
    t.datetime "password_expires_at", precision: nil, default: "2036-01-01 00:00:00"
    t.integer "notificaciones_sin_leer", default: 0, null: false
    t.boolean "recordatorios_activos", default: false, null: false
    t.boolean "alertar_notificaciones", default: false, null: false
    t.datetime "discontinued_at", precision: nil
    t.integer "dni"
    t.string "legajo"
    t.string "cuit"
    t.string "direccion_envio"
    t.string "sucursal"
    t.integer "tipo_usuario_id"
    t.integer "tienda_cliente_id"
    t.integer "visualizando_tienda_id"
    t.integer "local_id"
    t.bigint "visualizando_local_id"
    t.integer "servicio_de_impresion_id", default: 1, null: false
    t.string "vista_productos", default: "lista", null: false
    t.index ["cuenta_id", "dni"], name: "index_usuarios_on_cuenta_id_and_dni"
    t.index ["cuenta_id", "legajo"], name: "index_usuarios_on_cuenta_id_and_legajo"
    t.index ["cuenta_id", "login"], name: "index_usuarios_on_cuenta_id_and_login"
    t.index ["cuenta_id", "nombre"], name: "index_usuarios_on_cuenta_id_and_nombre"
    t.index ["cuenta_id"], name: "index_usuarios_on_cuenta_id"
    t.index ["cuit"], name: "index_usuarios_on_cuit"
    t.index ["discontinued_at"], name: "index_usuarios_on_discontinued_at"
    t.index ["dni"], name: "index_usuarios_on_dni"
    t.index ["legajo"], name: "index_usuarios_on_legajo"
    t.index ["local_id"], name: "index_usuarios_on_local_id"
    t.index ["login"], name: "index_usuarios_on_login"
    t.index ["tienda_cliente_id"], name: "index_usuarios_on_tienda_cliente_id"
    t.index ["visualizando_local_id"], name: "index_usuarios_on_visualizando_local_id"
    t.index ["visualizando_tienda_id"], name: "index_usuarios_on_visualizando_tienda_id"
  end

  create_table "usuarios_tiendas", id: false, charset: "latin1", collation: "latin1_swedish_ci", force: :cascade do |t|
    t.integer "usuario_id"
    t.integer "tienda_id"
    t.index ["tienda_id"], name: "index_usuarios_tiendas_on_tienda_id"
    t.index ["usuario_id"], name: "index_usuarios_tiendas_on_usuario_id"
  end

  add_foreign_key "answeres", "questiones"
  add_foreign_key "clientes_tiendas", "clientes"
  add_foreign_key "clientes_tiendas", "tiendas"
  add_foreign_key "clientes_turnos_entrega", "clientes"
  add_foreign_key "clientes_turnos_entrega", "turnos_entrega"
  add_foreign_key "cupones", "tiendas"
  add_foreign_key "descuentos_venta_mostrador", "tiendas"
  add_foreign_key "descuentos_venta_mostrador_clientes", "clientes"
  add_foreign_key "descuentos_venta_mostrador_clientes", "descuentos_venta_mostrador"
  add_foreign_key "pedidos", "cupones"
  add_foreign_key "pedidos", "descuentos_venta_mostrador"
  add_foreign_key "pedidos", "turnos_entrega"
  add_foreign_key "pedidos_medios_pago", "pedidos"
  add_foreign_key "pedidos_multiples", "cuentas"
  add_foreign_key "productos_stock_movimientos", "productos_stocks", column: "stock_id"
  add_foreign_key "productos_stock_movimientos", "usuarios"
  add_foreign_key "productos_stocks", "locales"
  add_foreign_key "productos_stocks", "productos"
  add_foreign_key "productos_stocks", "tiendas"
  add_foreign_key "questiones", "surveys"
  add_foreign_key "questiones_responses", "answeres"
  add_foreign_key "questiones_responses", "questiones"
  add_foreign_key "questiones_responses", "survey_responses"
  add_foreign_key "survey_responses", "surveys"
  add_foreign_key "survey_responses", "tiendas"
  add_foreign_key "survey_responses", "usuarios", column: "user_id"
  add_foreign_key "surveys", "tiendas"
  add_foreign_key "tiendas", "locales", column: "local_atencion_carrito_id"
  add_foreign_key "turnos_entrega_categorias", "categorias"
  add_foreign_key "turnos_entrega_categorias", "turnos_entrega"
end
